"use client";

import { useState, useEffect, useCallback, useMemo } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  ArrowLeft,
  Plus,
  Pencil,
  Trash2,
  Loader2,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Checkbox } from "@/components/ui/checkbox";
import * as paymentMethodsApi from "@/lib/api/payment-methods";
import {
  BACKEND_METHOD_LABELS,
  METHOD_TO_SOURCE_TYPES_FRONTEND,
  SOURCE_TYPE_LABELS,
} from "@/lib/api/payment-methods";
import { normalizePaymentSources } from "@/lib/normalize-payments";
import type { PaymentApp, PaymentMethod, PaymentSource } from "@/lib/types";

export default function AppDetailPage() {
  const params = useParams();
  const router = useRouter();
  const appId = params.id as string;
  const [app, setApp] = useState<PaymentApp | null>(null);
  const [sources, setSources] = useState<PaymentSource[]>([]);
  const [allMethods, setAllMethods] = useState<PaymentMethod[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [name, setName] = useState("");
  const [selectedMethodIds, setSelectedMethodIds] = useState<string[]>([]);
  const [addSourceOpen, setAddSourceOpen] = useState(false);
  const [addSourceMethod, setAddSourceMethod] = useState<string>("");
  const [addSourceType, setAddSourceType] = useState<string>("");
  const [addSourceSelectedId, setAddSourceSelectedId] = useState<string>("");
  const [addSourceSubmitting, setAddSourceSubmitting] = useState(false);
  const [allSourcesForAdd, setAllSourcesForAdd] = useState<PaymentSource[]>([]);
  const [deleteSourceId, setDeleteSourceId] = useState<string | null>(null);
  const [deletingSource, setDeletingSource] = useState(false);

  const loadApp = useCallback(async () => {
    if (!appId) return;
    const res = await paymentMethodsApi.getPaymentApp(appId);
    if (res.success && res.data) {
      setApp(res.data);
      setName(res.data.name);
    } else {
      setApp(null);
      toast.error("App not found");
    }
  }, [appId]);

  const loadSources = useCallback(async () => {
    if (!appId) return;
    const res = await paymentMethodsApi.getPaymentSources({ appId, all: true });
    if (res.success && res.data) {
      setSources(normalizePaymentSources(res.data));
    } else {
      setSources([]);
    }
  }, [appId]);

  const loadAllMethods = useCallback(async () => {
    const res = await paymentMethodsApi.getPaymentMethods({ management: true });
    if (res.success && res.data) {
      setAllMethods(res.data);
    } else {
      setAllMethods([]);
    }
  }, []);

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        await Promise.all([loadApp(), loadSources(), loadAllMethods()]);
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [loadApp, loadSources, loadAllMethods]);

  // Sync selectedMethodIds from server when app or allMethods loads
  useEffect(() => {
    if (app && allMethods.length) {
      const ids = app.supportedMethodIds;
      if (ids && ids.length) {
        setSelectedMethodIds(ids.map(String));
      } else {
        const keys = app.supportedMethods || [];
        setSelectedMethodIds(
          allMethods.filter((m) => m.key != null && keys.includes(m.key)).map((m) => m.id)
        );
      }
    }
  }, [app?.id, app?.supportedMethods?.join(","), app?.supportedMethodIds?.join(","), allMethods]);

  // Identifier = key for built-in methods, id for custom (key=null) so custom methods appear in Payment sources
  const supportedMethodIdentifiers = useMemo(
    () =>
      selectedMethodIds
        .map((id) => {
          const m = allMethods.find((x) => x.id === id);
          return m ? (m.key ?? m.id) : null;
        })
        .filter(Boolean) as string[],
    [allMethods, selectedMethodIds]
  );
  // Allowed source types per method (key or id): prefer API allowedSourceTypes, fallback to METHOD_TO_SOURCE_TYPES_FRONTEND by key
  const allowedSourceTypesByIdentifier = useMemo(() => {
    const map: Record<string, string[]> = {};
    supportedMethodIdentifiers.forEach((ident) => {
      const method = allMethods.find((m) => (m.key ?? m.id) === ident);
      map[ident] =
        (method?.allowedSourceTypes?.length
          ? method.allowedSourceTypes
          : METHOD_TO_SOURCE_TYPES_FRONTEND[method?.key ?? ""]) ?? [];
    });
    return map;
  }, [allMethods, supportedMethodIdentifiers]);
  // Selected methods (by id) for display and Add source dialog
  const selectedMethodsForAdd = useMemo(
    () => allMethods.filter((m) => selectedMethodIds.includes(m.id)),
    [allMethods, selectedMethodIds]
  );

  function toggleMethodById(id: string) {
    setSelectedMethodIds((prev) =>
      prev.includes(id) ? prev.filter((mid) => mid !== id) : [...prev, id]
    );
  }

  async function saveApp(e: React.FormEvent) {
    e.preventDefault();
    if (!appId || !name.trim()) return;
    setSaving(true);
    try {
      const res = await paymentMethodsApi.updatePaymentApp(appId, {
        name: name.trim(),
        supportedMethodIds: selectedMethodIds,
      });
      if (res.success && res.data) {
        setApp(res.data);
        toast.success("App updated");
      } else {
        toast.error(res.message || "Failed to update");
      }
    } catch {
      toast.error("Failed to update app");
    } finally {
      setSaving(false);
    }
  }

  const allowedSourceTypes = addSourceMethod
    ? (allowedSourceTypesByIdentifier[addSourceMethod] ?? METHOD_TO_SOURCE_TYPES_FRONTEND[addSourceMethod] ?? [])
    : [];

  // Map backend source type key to frontend type for filtering
  const BACKEND_TO_FRONTEND_TYPE: Record<string, PaymentSource["type"]> = {
    BANK: "bank",
    CREDIT_CARD: "credit_card",
    DEBIT_CARD: "debit_card",
    WALLET: "wallet",
    CASH: "cash",
  };

  // Sources available for the dropdown: match selected type, exclude already linked to this app
  const addSourceOptions = allSourcesForAdd.filter((s) => {
    const matchType = BACKEND_TO_FRONTEND_TYPE[addSourceType] === s.type;
    if (!matchType) return false;
    if (addSourceType === "CREDIT_CARD") {
      const rupee = !s.currency || s.currency.toUpperCase() === "INR";
      if (!rupee) return false;
    }
    const alreadyLinked = (s.linkedAppIds || []).includes(appId);
    return !alreadyLinked;
  });

  useEffect(() => {
    if (addSourceOpen) {
      paymentMethodsApi.getPaymentSources({ all: true }).then((res) => {
        if (res.success && res.data) {
          setAllSourcesForAdd(normalizePaymentSources(res.data));
        } else {
          setAllSourcesForAdd([]);
        }
      });
    }
  }, [addSourceOpen]);

  useEffect(() => {
    if (allowedSourceTypes.length && !allowedSourceTypes.includes(addSourceType)) {
      setAddSourceType(allowedSourceTypes[0] || "");
    }
  }, [addSourceMethod, addSourceType, allowedSourceTypes]);

  function openAddSource() {
    const firstIdent = supportedMethodIdentifiers[0] || "";
    setAddSourceMethod(firstIdent);
    setAddSourceType(
      (allowedSourceTypesByIdentifier[firstIdent] ?? METHOD_TO_SOURCE_TYPES_FRONTEND[firstIdent] ?? [])[0] || ""
    );
    setAddSourceSelectedId("");
    setAddSourceOpen(true);
  }

  async function submitAddSource() {
    if (!addSourceSelectedId.trim()) {
      toast.error("Select an existing source");
      return;
    }
    const method = allMethods.find((m) => (m.key ?? m.id) === addSourceMethod);
    const methodId = method?.id;
    if (!methodId) {
      toast.error("Select a method");
      return;
    }
    setAddSourceSubmitting(true);
    try {
      const res = await paymentMethodsApi.linkSourceToApp(appId, addSourceSelectedId, [methodId]);
      if (res.success) {
        toast.success("Source linked to app");
        setAddSourceOpen(false);
        loadSources();
      } else {
        toast.error(res.message || "Failed to link source");
      }
    } catch {
      toast.error("Failed to link source");
    } finally {
      setAddSourceSubmitting(false);
    }
  }

  async function handleDeleteSource(id: string) {
    setDeletingSource(true);
    try {
      const res = await paymentMethodsApi.unlinkSourceFromApp(appId, id);
      if (res.success) {
        toast.success("Source removed from app");
        setSources((prev) => prev.filter((s) => s.id !== id));
        setDeleteSourceId(null);
        loadSources();
      } else {
        toast.error(res.message || "Failed to remove");
      }
    } catch {
      toast.error("Failed to delete source");
    } finally {
      setDeletingSource(false);
    }
  }

  // Group sources by method (identifier = key or id for custom methods)
  const sourcesByMethod: Record<string, PaymentSource[]> = {};
  supportedMethodIdentifiers.forEach((ident) => {
    const method = allMethods.find((m) => (m.key ?? m.id) === ident);
    if (!method?.id) {
      sourcesByMethod[ident] = [];
      return;
    }
    sourcesByMethod[ident] = sources.filter((s) =>
      (s.linkedForAppMethodIds || []).includes(method.id)
    );
  });

  if (loading || !app) {
    return (
      <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-4xl mx-auto">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/apps">
              <ArrowLeft className="h-4 w-4" />
            </Link>
          </Button>
          <p className="text-muted-foreground">{loading ? "Loading…" : "App not found"}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-4xl mx-auto">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/dashboard/apps">
            <ArrowLeft className="h-4 w-4" />
            <span className="sr-only">Back</span>
          </Link>
        </Button>
        <div>
          <h1 className="text-xl font-semibold tracking-tight">{app.name}</h1>
          <p className="text-sm text-muted-foreground">Manage methods and payment sources for this app</p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">App details</CardTitle>
          <CardDescription>Edit name and supported payment methods</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={saveApp} className="flex flex-col gap-5">
            <div className="grid gap-2">
              <Label htmlFor="name">App name</Label>
              <Input
                id="name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. Google Pay"
              />
            </div>
            <div className="grid gap-2">
              <Label>Supported payment methods</Label>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {allMethods.map((method) => (
                  <label
                    key={method.id}
                    className="flex items-center gap-2 rounded-md border p-2 cursor-pointer hover:bg-muted/50"
                  >
                    <Checkbox
                      checked={selectedMethodIds.includes(method.id)}
                      onCheckedChange={() => toggleMethodById(method.id)}
                    />
                    <span className="text-sm">{method.name || method.key || method.type}</span>
                  </label>
                ))}
              </div>
            </div>
            <Button type="submit" disabled={saving}>
              {saving && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Save changes
            </Button>
          </form>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <CardTitle className="text-base">Payment sources</CardTitle>
              <CardDescription>
                Sources linked to this app, by method. Add bank accounts, cards, or wallets used in this app.
              </CardDescription>
            </div>
            <Button
              onClick={openAddSource}
              disabled={supportedMethodIdentifiers.length === 0}
              size="sm"
            >
              <Plus className="h-4 w-4 mr-2" />
              Add source
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          {supportedMethodIdentifiers.length === 0 ? (
            <p className="text-sm text-muted-foreground">Add at least one supported method above, then add sources.</p>
          ) : (
            <div className="space-y-6">
              {supportedMethodIdentifiers.map((ident) => {
                const list = sourcesByMethod[ident] || [];
                const method = allMethods.find((m) => (m.key ?? m.id) === ident);
                const methodName = method?.name ?? BACKEND_METHOD_LABELS[method?.key ?? ""] ?? method?.key ?? ident;
                return (
                  <div key={ident}>
                    <div className="flex items-center gap-2 mb-2">
                      <span className="text-sm font-medium">{methodName}</span>
                      <Badge variant="secondary" className="font-normal">
                        {list.length} source{list.length !== 1 ? "s" : ""}
                      </Badge>
                    </div>
                    {list.length === 0 ? (
                      <p className="text-sm text-muted-foreground pl-1">No sources for this method yet.</p>
                    ) : (
                      <ul className="space-y-1.5">
                        {list.map((s) => (
                          <li
                            key={s.id}
                            className="flex items-center justify-between gap-2 rounded-md border px-3 py-2 text-sm"
                          >
                            <div>
                              <span className="font-medium">{s.name}</span>
                              {s.bankName && (
                                <span className="text-muted-foreground ml-2">({s.bankName})</span>
                              )}
                              <span className="ml-2 text-muted-foreground">
                                {SOURCE_TYPE_LABELS[s.type] || s.type}
                              </span>
                            </div>
                            <Button
                              variant="ghost"
                              size="icon"
                              className="text-destructive hover:text-destructive h-8 w-8"
                              onClick={() => setDeleteSourceId(s.id)}
                            >
                              <Trash2 className="h-4 w-4" />
                              <span className="sr-only">Delete</span>
                            </Button>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </CardContent>
      </Card>
      <Dialog open={addSourceOpen} onOpenChange={setAddSourceOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add payment source</DialogTitle>
            <DialogDescription>
              Link an existing payment source to this app. Choose the method and type, then select a source.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label>Method</Label>
              <Select value={addSourceMethod} onValueChange={setAddSourceMethod}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {supportedMethodIdentifiers.map((ident) => {
                    const method = allMethods.find((m) => (m.key ?? m.id) === ident);
                    return (
                      <SelectItem key={ident} value={ident}>
                        {method?.name ?? BACKEND_METHOD_LABELS[method?.key ?? ""] ?? method?.key ?? ident}
                      </SelectItem>
                    );
                  })}
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-2">
              <Label>Source type</Label>
              <Select value={addSourceType} onValueChange={(v) => { setAddSourceType(v); setAddSourceSelectedId(""); }}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {allowedSourceTypes.map((st) => (
                    <SelectItem key={st} value={st}>
                      {SOURCE_TYPE_LABELS[st] ?? st}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-2">
              <Label>Select existing source</Label>
              <Select
                value={addSourceSelectedId || ""}
                onValueChange={setAddSourceSelectedId}
              >
                <SelectTrigger>
                  <SelectValue
                    placeholder={
                      addSourceType === "BANK"
                        ? "Choose a bank account…"
                        : addSourceType === "CREDIT_CARD"
                          ? "Choose a credit card (INR)…"
                          : addSourceType === "DEBIT_CARD"
                            ? "Choose a debit card…"
                            : addSourceType === "WALLET"
                              ? "Choose a wallet…"
                              : "Choose a source…"
                    }
                  />
                </SelectTrigger>
                <SelectContent>
                  {addSourceOptions.length === 0 ? (
                    <div className="py-4 px-2 text-center text-sm text-muted-foreground">
                      No unlinked sources for this type. Create sources from Payment Sources first.
                    </div>
                  ) : (
                    addSourceOptions.map((s) => (
                      <SelectItem key={s.id} value={s.id}>
                        {s.name}
                        {s.bankName ? ` (${s.bankName})` : ""}
                        {s.lastFourDigits ? ` •••• ${s.lastFourDigits}` : ""}
                      </SelectItem>
                    ))
                  )}
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAddSourceOpen(false)}>
              Cancel
            </Button>
            <Button
              onClick={submitAddSource}
              disabled={addSourceSubmitting || !addSourceSelectedId}
            >
              {addSourceSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Link source
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <AlertDialog open={!!deleteSourceId} onOpenChange={(open) => !open && setDeleteSourceId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Remove this source?</AlertDialogTitle>
            <AlertDialogDescription>
              This source will be removed from this app. Transactions that used it may still show the source name.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={deletingSource}>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => deleteSourceId && handleDeleteSource(deleteSourceId)}
              disabled={deletingSource}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {deletingSource ? "Removing…" : "Remove"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
