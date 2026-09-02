"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { Plus, Pencil, Trash2, Smartphone } from "lucide-react";
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
import { BACKEND_METHOD_LABELS } from "@/lib/api/payment-methods";
import type { PaymentApp } from "@/lib/types";

export default function AppsListPage() {
  const [apps, setApps] = useState<PaymentApp[]>([]);
  const [loading, setLoading] = useState(true);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  async function load() {
    setLoading(true);
    try {
      const res = await paymentMethodsApi.getPaymentApps({ all: true });
      if (res.success && res.data) setApps(res.data);
      else setApps([]);
    } catch {
      toast.error("Failed to load apps");
      setApps([]);
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
      const res = await paymentMethodsApi.deletePaymentApp(id);
      if (res.success) {
        toast.success("App deleted");
        setApps((prev) => prev.filter((a) => a.id !== id));
        setDeleteId(null);
      } else {
        toast.error(res.message || "Failed to delete");
      }
    } catch {
      toast.error("Failed to delete app");
    } finally {
      setDeleting(false);
    }
  }

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-4xl mx-auto">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Payment Apps</h1>
          <p className="text-sm text-muted-foreground">
            Manage apps like Google Pay, PhonePe, Paytm, CRED, and bank apps. Set supported methods and sources per app.
          </p>
        </div>
        <Button asChild>
          <Link href="/dashboard/apps/new">
            <Plus className="h-4 w-4 mr-2" />
            Add app
          </Link>
        </Button>
      </div>

      {loading ? (
        <Card>
          <CardContent className="flex items-center justify-center py-12">
            <p className="text-sm text-muted-foreground">Loading apps…</p>
          </CardContent>
        </Card>
      ) : apps.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12 gap-4">
            <Smartphone className="h-10 w-10 text-muted-foreground" />
            <p className="text-sm text-muted-foreground">No payment apps yet.</p>
            <Button asChild>
              <Link href="/dashboard/apps/new">Add your first app</Link>
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-3">
          {apps.map((app) => (
            console.log("app", app),
            <Card key={app.id}>
              <CardHeader className="pb-2">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2 flex-wrap">
                    <CardTitle className="text-base">{app.name}</CardTitle>
                    {!app.isActive && (
                      <Badge variant="secondary">Inactive</Badge>
                    )}
                  </div>
                  <div className="flex items-center gap-1">
                    <Button variant="ghost" size="icon" asChild>
                      <Link href={`/dashboard/apps/${app.id}`}>
                        <Pencil className="h-4 w-4" />
                        <span className="sr-only">Edit</span>
                      </Link>
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={() => setDeleteId(app.id)}
                      className="text-destructive hover:text-destructive"
                    >
                      <Trash2 className="h-4 w-4" />
                      <span className="sr-only">Delete</span>
                    </Button>
                  </div>
                </div>
                <CardDescription className="sr-only">Supported methods and sources</CardDescription>
              </CardHeader>
              <CardContent className="pt-0">
                <div className="flex flex-wrap gap-1.5">
                  {(app.supportedMethods || []).length === 0 ? (
                    <span className="text-sm text-muted-foreground">No methods set</span>
                  ) : (
                    (app.supportedMethods || []).map((key) => (
                      <Badge key={key} variant="outline" className="font-normal">
                        {BACKEND_METHOD_LABELS[key] ?? key}
                      </Badge>
                    ))
                  )}
                </div>
                <div className="mt-3">
                  <Button variant="outline" size="sm" asChild>
                    <Link href={`/dashboard/apps/${app.id}`}>Manage methods & sources</Link>
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      <AlertDialog open={!!deleteId} onOpenChange={(open) => !open && setDeleteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete app?</AlertDialogTitle>
            <AlertDialogDescription>
              This will remove the app and all sources linked to it. This cannot be undone.
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
