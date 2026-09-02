"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  ArrowLeft,
  Loader2,
  Building2,
  CreditCard,
  Wallet,
  Banknote,
  Trash2,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
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
import * as paymentSourcesApi from "@/lib/api/payment-sources";
import type { PaymentSource, PaymentSourceType } from "@/lib/types";

const SOURCE_TYPE_LABELS: Record<PaymentSourceType, string> = {
  bank: "Bank account",
  credit_card: "Credit card",
  debit_card: "Debit card",
  wallet: "Wallet",
  cash: "Cash",
};

const SOURCE_TYPE_ICONS: Record<PaymentSourceType, React.ReactNode> = {
  bank: <Building2 className="h-4 w-4" />,
  credit_card: <CreditCard className="h-4 w-4" />,
  debit_card: <CreditCard className="h-4 w-4" />,
  wallet: <Wallet className="h-4 w-4" />,
  cash: <Banknote className="h-4 w-4" />,
};

function formatBalance(balance: number, currency?: string): string {
  const abs = Math.abs(balance);
  const formatted = new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: currency || "INR",
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(abs);
  return balance < 0 ? `-${formatted}` : formatted;
}

function formatDate(iso: string): string {
  try {
    return new Date(iso).toLocaleDateString(undefined, {
      dateStyle: "medium",
    });
  } catch {
    return iso;
  }
}

export default function PaymentSourceDetailPage() {
  const params = useParams();
  const router = useRouter();
  const id = params.id as string;
  const [source, setSource] = useState<PaymentSource | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [name, setName] = useState("");
  const [bankName, setBankName] = useState("");
  const [isActive, setIsActive] = useState(true);
  const [deleteOpen, setDeleteOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const loadSource = useCallback(async () => {
    if (!id) return;
    const res = await paymentSourcesApi.getPaymentSource(id);
    if (res.success && res.data) {
      const d = res.data;
      setSource(d);
      setName(d.name);
      setBankName(d.bankName ?? "");
      setIsActive(d.isActive ?? true);
    } else {
      setSource(null);
      toast.error(res.message ?? "Payment source not found.");
    }
  }, [id]);

  useEffect(() => {
    setLoading(true);
    loadSource().finally(() => setLoading(false));
  }, [loadSource]);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!id || !name.trim()) return;
    setSaving(true);
    try {
      const res = await paymentSourcesApi.updatePaymentSource(id, {
        name: name.trim(),
        bankName: bankName.trim() || undefined,
        isActive,
      });
      if (res.success && res.data) {
        setSource(res.data);
        toast.success("Payment source updated.");
      } else {
        toast.error(res.message ?? "Failed to update.");
      }
    } catch {
      toast.error("Failed to update payment source.");
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!id) return;
    setDeleting(true);
    try {
      const res = await paymentSourcesApi.deletePaymentSource(id);
      if (res.success) {
        toast.success("Payment source deleted.");
        router.push("/dashboard/payment-sources");
      } else {
        toast.error(res.message ?? "Failed to delete.");
      }
    } catch {
      toast.error("Failed to delete payment source.");
    } finally {
      setDeleting(false);
      setDeleteOpen(false);
    }
  }

  if (loading || !source) {
    return (
      <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-xl mx-auto">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/payment-sources">
              <ArrowLeft className="h-4 w-4" />
              <span className="sr-only">Back</span>
            </Link>
          </Button>
          <p className="text-muted-foreground">
            {loading ? "Loading…" : "Payment source not found"}
          </p>
        </div>
      </div>
    );
  }

  const balance = typeof source.balance === "number" ? source.balance : 0;
  const currency = source.currency ?? "INR";

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-xl mx-auto">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/dashboard/payment-sources">
            <ArrowLeft className="h-4 w-4" />
            <span className="sr-only">Back</span>
          </Link>
        </Button>
        <div className="flex-1 min-w-0">
          <h1 className="text-xl font-semibold tracking-tight truncate">{source.name}</h1>
          <p className="text-sm text-muted-foreground">
            View and edit this payment source
          </p>
        </div>
      </div>

      {/* Overview */}
      <Card>
        <CardHeader className="pb-2">
          <div className="flex flex-wrap items-center gap-2">
            <Badge variant="outline" className="font-normal flex items-center gap-1">
              {SOURCE_TYPE_ICONS[source.type]}
              {SOURCE_TYPE_LABELS[source.type]}
            </Badge>
            {!source.isActive && (
              <Badge variant="secondary">Inactive</Badge>
            )}
            {(source.linkedAppIds?.length ?? 0) > 0 && (
              <>
                {(source.linkedAppIds ?? []).map((appId, i) => (
                  <Badge key={appId} variant="secondary">
                    <Link
                      href={`/dashboard/apps/${appId}`}
                      className="hover:underline"
                    >
                      {source.linkedAppNames?.[i] ?? appId}
                    </Link>
                  </Badge>
                ))}
              </>
            )}
          </div>
          <CardTitle className="text-2xl mt-2 tabular-nums">
            <span className={balance >= 0 ? "text-foreground" : "text-destructive"}>
              {formatBalance(balance, currency)}
            </span>
          </CardTitle>
          <CardDescription>
            {source.type === "debit_card" && source.linkedBankSourceName && (
              <span className="block">Same as linked bank account ({source.linkedBankSourceName})</span>
            )}
            {source.bankName && <span>{source.bankName}</span>}
            {source.lastFourDigits && (
              <span className="ml-1">•••• {source.lastFourDigits}</span>
            )}
            {source.type === "wallet" && source.walletName && (
              <span className="ml-1"> • {source.walletName}</span>
            )}
            {source.type === "cash" && "Physical cash"}
            {source.createdAt && (
              <span className="block mt-1">
                Added {formatDate(source.createdAt)}
              </span>
            )}
          </CardDescription>
        </CardHeader>
      </Card>

      {/* Edit form */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Edit details</CardTitle>
          <CardDescription>Change name, bank/issuer, and active status</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSave} className="flex flex-col gap-5">
            <div className="grid gap-2">
              <Label htmlFor="name">Display name</Label>
              <Input
                id="name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. HDFC Savings"
                required
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="bankName">Bank / issuer name</Label>
              <Input
                id="bankName"
                value={bankName}
                onChange={(e) => setBankName(e.target.value)}
                placeholder="e.g. HDFC Bank, ICICI Bank"
              />
            </div>
            <div className="flex items-center gap-2">
              <Checkbox
                id="isActive"
                checked={isActive}
                onCheckedChange={(v) => setIsActive(v === true)}
              />
              <Label htmlFor="isActive" className="cursor-pointer font-normal">
                Active (show in payment source list and when adding transactions)
              </Label>
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
                Delete source
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>

      <AlertDialog open={deleteOpen} onOpenChange={setDeleteOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete this payment source?</AlertDialogTitle>
            <AlertDialogDescription>
              This will remove &quot;{source.name}&quot;. Transactions that used this source may
              need to be reassigned. This cannot be undone.
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
