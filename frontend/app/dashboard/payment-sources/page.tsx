"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import {
  Plus,
  Pencil,
  Trash2,
  CreditCard,
  Loader2,
  Building2,
  Wallet,
  Banknote,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
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
import type { ApiResponse, PaymentSource, PaymentSourceType } from "@/lib/types";
import * as paymentSourcesApi from "@/lib/api/payment-sources";
import { toast } from "sonner";

// Mock data for UI only — balance goes down with expenses, up with income
const MOCK_SOURCES: PaymentSource[] = [
  {
    id: "1",
    name: "HDFC Savings",
    type: "bank",
    balance: 125000,
    currency: "INR",
    bankName: "HDFC Bank",
    accountNumber: "****4521",
    ifsc: "HDFC0001234",
    isActive: true,
    createdAt: new Date().toISOString(),
  },
  {
    id: "2",
    name: "ICICI Credit Card",
    type: "credit_card",
    balance: -18450,
    currency: "INR",
    bankName: "ICICI Bank",
    lastFourDigits: "3456",
    cardNetwork: "Visa",
    creditLimit: 100000,
    isActive: true,
    createdAt: new Date().toISOString(),
  },
  {
    id: "3",
    name: "SBI Debit Card",
    type: "debit_card",
    balance: 42000,
    currency: "INR",
    bankName: "State Bank of India",
    lastFourDigits: "7890",
    cardNetwork: "RuPay",
    isActive: true,
    createdAt: new Date().toISOString(),
  },
  {
    id: "4",
    name: "Google Pay",
    type: "wallet",
    balance: 3500,
    currency: "INR",
    walletName: "Google Pay",
    upiIds: ["user@okaxis"],
    isActive: true,
    createdAt: new Date().toISOString(),
  },
  {
    id: "5",
    name: "Physical cash",
    type: "cash",
    balance: 2500,
    currency: "INR",
    isActive: true,
    createdAt: new Date().toISOString(),
  },
];

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

export default function PaymentSourcesPage() {
    // change to use api
    const [sources, setSources] = useState<PaymentSource[]>([]);
    const [loading, setLoading] = useState(false);
    const [deleteId, setDeleteId] = useState<string | null>(null);
    const [deleting, setDeleting] = useState(false);

    useEffect(() => {
        setLoading(true);
        (async () => {
            try {
                const res = await paymentSourcesApi.getPaymentSources();
                if (res.success && res.data) {
                    console.log(res.data);
                    setSources(res.data);
                } else {
                    toast.error(res.message ?? "Failed to load payment sources.");
                }
            } catch {
                toast.error("Failed to load payment sources.");
            } finally {
                setLoading(false);
            }
        })();
    }, []);

  function handleDelete(id: string) {
    setDeleting(true);
    (async () => {
        try {
            const res = await paymentSourcesApi.deletePaymentSource(id);
            if (res.success) {
                toast.success("Payment source deleted.");
            } else {
                toast.error(res.message ?? "Failed to delete payment source.");
            }
        } catch {
            toast.error("Failed to delete payment source.");
        } finally {
            setDeleting(false);
        }
    })();
  }

  function getSourceSubtitle(source: PaymentSource): string | null {
    if (source.type === "bank" && source.bankName) return source.bankName;
    if (source.type === "credit_card" || source.type === "debit_card") {
      const parts = [source.bankName, source.lastFourDigits && `****${source.lastFourDigits}`].filter(Boolean);
      return parts.length ? parts.join(" • ") : null;
    }
    if (source.type === "wallet" && source.walletName) return source.walletName;
    if (source.type === "cash") return "Physical cash";
    return null;
  }

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-4xl mx-auto">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Payment Sources</h1>
          <p className="text-sm text-muted-foreground">
            Bank accounts, cards, wallets, and cash. Balance goes down when you add expenses and up when you add income.
          </p>
        </div>
        <Button asChild>
          <Link href="/dashboard/payment-sources/new">
            <Plus className="h-4 w-4 mr-2" />
            Add source
          </Link>
        </Button>
      </div>

      {loading ? (
        <Card>
          <CardContent className="flex items-center justify-center py-12">
            <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
            <p className="ml-2 text-sm text-muted-foreground">Loading sources…</p>
          </CardContent>
        </Card>
      ) : sources.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12 gap-4">
            <CreditCard className="h-10 w-10 text-muted-foreground" />
            <p className="text-sm text-muted-foreground">No payment sources yet.</p>
            <Button asChild>
              <Link href="/dashboard/payment-sources/new">Add your first source</Link>
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-3">
          {sources.map((source) => (
            <Card key={source.id}>
              <CardHeader className="pb-2">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2 flex-wrap">
                    <CardTitle className="text-base">{source.name}</CardTitle>
                    <Badge variant="outline" className="font-normal flex items-center gap-1">
                      {SOURCE_TYPE_ICONS[source.type]}
                      {SOURCE_TYPE_LABELS[source.type]}
                    </Badge>
                    {!source.isActive && (
                      <Badge variant="secondary">Inactive</Badge>
                    )}
                  </div>
                  <div className="flex items-center gap-3">
                    <span
                      className={`text-sm font-medium tabular-nums ${
                        source.balance >= 0 ? "text-foreground" : "text-destructive"
                      }`}
                    >
                      {formatBalance(source.balance, source.currency)}
                    </span>
                    <div className="flex items-center gap-1">
                      <Button variant="ghost" size="icon" asChild>
                        <Link href={`/dashboard/payment-sources/${source.id}`}>
                          <Pencil className="h-4 w-4" />
                          <span className="sr-only">Edit</span>
                        </Link>
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => setDeleteId(source.id)}
                        className="text-destructive hover:text-destructive"
                      >
                        <Trash2 className="h-4 w-4" />
                        <span className="sr-only">Delete</span>
                      </Button>
                    </div>
                  </div>
                </div>
                <CardDescription>
                  {getSourceSubtitle(source)}
                  {source.type === "bank" && source.accountNumber && (
                    <span className="ml-1"> • {source.accountNumber}</span>
                  )}
                  {source.type === "wallet" && source.upiIds?.length ? (
                    <span className="ml-1"> • {source.upiIds[0]}</span>
                  ) : null}
                </CardDescription>
              </CardHeader>
            </Card>
          ))}
        </div>
      )}

      <AlertDialog open={!!deleteId} onOpenChange={(open) => !open && setDeleteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete payment source?</AlertDialogTitle>
            <AlertDialogDescription>
              This will remove the source. Transactions linked to it may need to be updated. This cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={deleting}>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => deleteId && handleDelete(deleteId)}
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
