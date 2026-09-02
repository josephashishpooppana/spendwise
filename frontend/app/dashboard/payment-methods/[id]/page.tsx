"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { ArrowLeft, Loader2, Trash2, ChevronDown } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Checkbox } from "@/components/ui/checkbox";
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
import * as paymentMethodsApi from "@/lib/api/payment-methods";
import type { SourceTypeOption } from "@/lib/api/payment-methods";
import type { PaymentMethod } from "@/lib/types";

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString(undefined, { dateStyle: "medium" });
  } catch {
    return iso;
  }
}

export default function PaymentMethodDetailPage() {
  const params = useParams();
  const router = useRouter();
  const id = params.id as string;
  const [method, setMethod] = useState<PaymentMethod | null>(null);
  const [sourceTypes, setSourceTypes] = useState<SourceTypeOption[]>([]);
  const [loadingTypes, setLoadingTypes] = useState(true);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [name, setName] = useState("");
  const [selectedKeys, setSelectedKeys] = useState<string[]>([]);
  const [popoverOpen, setPopoverOpen] = useState(false);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);

  useEffect(() => {
    let cancelled = false;
    paymentMethodsApi.getSourceTypes().then((res) => {
      if (cancelled) return;
      setLoadingTypes(false);
      if (res.success && res.data) setSourceTypes(res.data);
    });
    return () => {
      cancelled = true;
    };
  }, []);

  const loadMethod = useCallback(async () => {
    if (!id) return;
    const res = await paymentMethodsApi.getPaymentMethod(id);
    if (res.success && res.data) {
      const d = res.data;
      setMethod(d);
      setName(d.name ?? "");
      setSelectedKeys(d.allowedSourceTypes ?? []);
    } else {
      setMethod(null);
      toast.error(res.message ?? "Payment method not found.");
    }
  }, [id]);

  useEffect(() => {
    setLoading(true);
    loadMethod().finally(() => setLoading(false));
  }, [loadMethod]);

  function toggleSourceType(key: string) {
    setSelectedKeys((prev) =>
      prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key]
    );
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!id || !method) return;
    if (method.isBuiltIn) {
      toast.error("Built-in payment methods cannot be edited.");
      return;
    }
    const trimmedName = name.trim();
    if (!trimmedName) {
      toast.error("Display name is required.");
      return;
    }
    if (selectedKeys.length === 0) {
      toast.error("Select at least one payment source type.");
      return;
    }
    setSaving(true);
    try {
      const res = await paymentMethodsApi.updatePaymentMethod(id, {
        name: trimmedName,
        sourceTypeKeys: selectedKeys,
      });
      if (res.success && res.data) {
        setMethod(res.data);
        toast.success("Payment method updated.");
      } else {
        toast.error(res.message ?? "Failed to update.");
      }
    } catch {
      toast.error("Failed to update payment method.");
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!id || !method) return;
    if (method.isBuiltIn) return;
    setDeleting(true);
    try {
      const res = await paymentMethodsApi.deletePaymentMethod(id);
      if (res.success) {
        toast.success("Payment method deleted.");
        router.push("/dashboard/payment-methods");
      } else {
        toast.error(res.message ?? "Failed to delete.");
      }
    } catch {
      toast.error("Failed to delete payment method.");
    } finally {
      setDeleting(false);
      setDeleteOpen(false);
    }
  }

  if (loading || !method) {
    return (
      <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-xl mx-auto">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/payment-methods">
              <ArrowLeft className="h-4 w-4" />
              <span className="sr-only">Back</span>
            </Link>
          </Button>
          <p className="text-muted-foreground">
            {loading ? "Loading…" : "Payment method not found"}
          </p>
        </div>
      </div>
    );
  }

  const isBuiltIn = method.isBuiltIn ?? false;
  const selectedLabels = selectedKeys
    .map((k) => sourceTypes.find((s) => s.key === k)?.label ?? k)
    .join(", ");
  const triggerLabel = selectedKeys.length
    ? (selectedKeys.length === 1 ? selectedLabels : `${selectedKeys.length} types selected`)
    : "Select source types";

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-xl mx-auto">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/dashboard/payment-methods">
            <ArrowLeft className="h-4 w-4" />
            <span className="sr-only">Back</span>
          </Link>
        </Button>
        <div className="flex-1 min-w-0">
          <h1 className="text-xl font-semibold tracking-tight truncate">
            {method.name || method.key || method.type || method.id}
          </h1>
          <p className="text-sm text-muted-foreground">
            {isBuiltIn ? "Built-in method (read-only)" : "View and edit this payment method"}
          </p>
        </div>
      </div>

      <Card>
        <CardHeader className="pb-2">
          <div className="flex flex-wrap items-center gap-2">
            {method.key && (
              <Badge variant="outline" className="font-normal">
                {method.key}
              </Badge>
            )}
            {isBuiltIn && <Badge variant="secondary">Built-in</Badge>}
            {method.allowedSourceTypes && method.allowedSourceTypes.length > 0 && (
              <span className="text-sm text-muted-foreground">
                Source types: {method.allowedSourceTypes.join(", ")}
              </span>
            )}
          </div>
          {method.createdAt && (
            <CardDescription>Added {formatDate(method.createdAt)}</CardDescription>
          )}
        </CardHeader>
      </Card>

      {!isBuiltIn && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">Edit details</CardTitle>
            <CardDescription>Display name and payment source types (from database)</CardDescription>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleSave} className="flex flex-col gap-5">
              <div className="grid gap-2">
                <Label htmlFor="name">Display name</Label>
                <Input
                  id="name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. NEFT, IMPS"
                  required
                />
              </div>
              <div className="grid gap-2">
                <Label>Payment source types</Label>
                <Popover open={popoverOpen} onOpenChange={setPopoverOpen}>
                  <PopoverTrigger asChild>
                    <Button
                      type="button"
                      variant="outline"
                      className="w-full justify-between font-normal"
                      disabled={loadingTypes}
                    >
                      <span className={selectedKeys.length ? "text-foreground" : "text-muted-foreground"}>
                        {loadingTypes ? "Loading…" : triggerLabel}
                      </span>
                      <ChevronDown className="h-4 w-4 opacity-50" />
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-full min-w-[var(--radix-popover-trigger-width)] p-2" align="start">
                    <div className="max-h-60 overflow-y-auto space-y-1">
                      {sourceTypes.map((st) => (
                        <label
                          key={st.key}
                          className="flex items-center gap-2 rounded-md px-2 py-1.5 text-sm cursor-pointer hover:bg-muted/60"
                        >
                          <Checkbox
                            checked={selectedKeys.includes(st.key)}
                            onCheckedChange={() => toggleSourceType(st.key)}
                          />
                          <span>{st.label}</span>
                        </label>
                      ))}
                      {!loadingTypes && sourceTypes.length === 0 && (
                        <p className="text-sm text-muted-foreground px-2 py-2">No source types found.</p>
                      )}
                    </div>
                  </PopoverContent>
                </Popover>
                <p className="text-xs text-muted-foreground">Select at least one type.</p>
              </div>
              <div className="flex gap-3 pt-2">
                <Button type="submit" disabled={saving}>
                  {saving && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  Save changes
                </Button>
                <Button
                  type="button"
                  variant="destructive"
                  onClick={() => setDeleteOpen(true)}
                  className="ml-auto"
                >
                  <Trash2 className="h-4 w-4 mr-2" />
                  Delete method
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      )}

      <AlertDialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete this payment method?</AlertDialogTitle>
            <AlertDialogDescription>
              This will remove &quot;{method.name || method.key}&quot;. This cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={deleting}>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              disabled={deleting}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {deleting ? "Deleting…" : "Delete"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
