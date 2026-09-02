"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { Plus, Pencil, Trash2, CreditCard } from "lucide-react";
import { toast } from "sonner";
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
import * as paymentMethodsApi from "@/lib/api/payment-methods";
import type { PaymentMethod } from "@/lib/types";

export default function PaymentMethodsListPage() {
  const [methods, setMethods] = useState<PaymentMethod[]>([]);
  const [loading, setLoading] = useState(true);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  async function load() {
    setLoading(true);
    try {
      const res = await paymentMethodsApi.getPaymentMethods({ management: true });
      if (res.success && res.data) setMethods(res.data);
      else setMethods([]);
    } catch {
      toast.error("Failed to load payment methods");
      setMethods([]);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function handleDelete(id: string) {
    setDeleting(true);
    try {
      const res = await paymentMethodsApi.deletePaymentMethod(id);
      if (res.success) {
        toast.success("Payment method deleted");
        setMethods((prev) => prev.filter((m) => m.id !== id));
        setDeleteId(null);
      } else {
        toast.error(res.message || "Failed to delete");
      }
    } catch {
      toast.error("Failed to delete payment method");
    } finally {
      setDeleting(false);
    }
  }

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-4xl mx-auto">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Payment Methods</h1>
          <p className="text-sm text-muted-foreground">
            Manage payment methods. Built-in methods are read-only; add custom methods with a display name and allowed payment source types.
          </p>
        </div>
        <Button asChild>
          <Link href="/dashboard/payment-methods/new">
            <Plus className="h-4 w-4 mr-2" />
            Add method
          </Link>
        </Button>
      </div>

      {loading ? (
        <Card>
          <CardContent className="flex items-center justify-center py-12">
            <p className="text-sm text-muted-foreground">Loading payment methods…</p>
          </CardContent>
        </Card>
      ) : methods.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12 gap-4">
            <CreditCard className="h-10 w-10 text-muted-foreground" />
            <p className="text-sm text-muted-foreground">No payment methods found.</p>
            <Button asChild>
              <Link href="/dashboard/payment-methods/new">Add your first custom method</Link>
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-3">
          {methods.map((method) => (
            <Card key={method.id}>
              <CardHeader className="pb-2">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2 flex-wrap">
                    <CardTitle className="text-base">{method.name || method.key || method.type || method.id}</CardTitle>
                    {method.key && (
                      <Badge variant="outline" className="font-normal">
                        {method.key}
                      </Badge>
                    )}
                    {method.isBuiltIn && (
                      <Badge variant="secondary">Built-in</Badge>
                    )}
                    {method.allowedSourceTypes && method.allowedSourceTypes.length > 0 && (
                      <span className="text-xs text-muted-foreground">
                        {method.allowedSourceTypes.join(", ")}
                      </span>
                    )}
                  </div>
                  {!method.isBuiltIn && (
                    <div className="flex items-center gap-1">
                      <Button variant="ghost" size="icon" asChild>
                        <Link href={`/dashboard/payment-methods/${method.id}`}>
                          <Pencil className="h-4 w-4" />
                          <span className="sr-only">Edit</span>
                        </Link>
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => setDeleteId(method.id)}
                        className="text-destructive hover:text-destructive"
                      >
                        <Trash2 className="h-4 w-4" />
                        <span className="sr-only">Delete</span>
                      </Button>
                    </div>
                  )}
                </div>
                <CardDescription className="sr-only">Payment method type</CardDescription>
              </CardHeader>
            </Card>
          ))}
        </div>
      )}

      <AlertDialog open={!!deleteId} onOpenChange={(open) => !open && setDeleteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete payment method?</AlertDialogTitle>
            <AlertDialogDescription>
              This will remove this custom payment method. Transactions that used it may still reference it. This cannot be undone.
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
