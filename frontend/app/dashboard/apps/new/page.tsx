"use client";

import { useCallback, useState, useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeft, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import * as paymentMethodsApi from "@/lib/api/payment-methods";
import { SOURCE_TYPE_LABELS } from "@/lib/api/payment-methods";
import type { PaymentMethod, PaymentSource } from "@/lib/types";

export default function NewAppPage() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [selectedMethodIds, setSelectedMethodIds] = useState<string[]>([]);
  const [selectedSourceIds, setSelectedSourceIds] = useState<string[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [allMethods, setAllMethods] = useState<PaymentMethod[]>([]);
  const [allSources, setAllSources] = useState<PaymentSource[]>([]);
  const [methodsLoading, setMethodsLoading] = useState(true);
  const [sourcesLoading, setSourcesLoading] = useState(true);

  const loadPaymentMethods = useCallback(async () => {
    setMethodsLoading(true);
    const res = await paymentMethodsApi.getPaymentMethods({ management: true });
    if (res.success && res.data) {
      setAllMethods(res.data);
    } else {
      setAllMethods([]);
    }
    setMethodsLoading(false);
  }, []);

  const loadSources = useCallback(async () => {
    setSourcesLoading(true);
    const res = await paymentMethodsApi.getPaymentSources({ all: true });
    if (res.success && res.data) {
      setAllSources(res.data);
    } else {
      setAllSources([]);
    }
    setSourcesLoading(false);
  }, []);

  useEffect(() => {
    loadPaymentMethods();
  }, [loadPaymentMethods]);

  useEffect(() => {
    loadSources();
  }, [loadSources]);

  function toggleMethodById(id: string) {
    setSelectedMethodIds((prev) =>
      prev.includes(id) ? prev.filter((m) => m !== id) : [...prev, id]
    );
  }

  function toggleSource(id: string) {
    setSelectedSourceIds((prev) =>
      prev.includes(id) ? prev.filter((s) => s !== id) : [...prev, id]
    );
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    const trimmed = name.trim();
    if (!trimmed) {
      toast.error("Enter app name");
      return;
    }
    setSubmitting(true);
    try {
      const res = await paymentMethodsApi.createPaymentApp({
        name: trimmed,
        supportedMethodIds: selectedMethodIds.length ? selectedMethodIds : undefined,
        isActive: true,
      });
      if (res.success && res.data) {
        const appId = res.data.id;
        for (const sourceId of selectedSourceIds) {
          await paymentMethodsApi.linkSourceToApp(appId, sourceId, selectedMethodIds);
        }
        toast.success("App created");
        router.push(`/dashboard/apps/${appId}`);
      } else {
        toast.error(res.message || "Failed to create app");
      }
    } catch {
      toast.error("Something went wrong");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-xl mx-auto">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/dashboard/apps">
            <ArrowLeft className="h-4 w-4" />
            <span className="sr-only">Back</span>
          </Link>
        </Button>
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Add payment app</h1>
          <p className="text-sm text-muted-foreground">e.g. Google Pay, PhonePe, Paytm, CRED, or your bank app</p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">App details</CardTitle>
          <CardDescription>Name and payment methods this app supports</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={onSubmit} className="flex flex-col gap-5">
            <div className="grid gap-2">
              <Label htmlFor="name">App name</Label>
              <Input
                id="name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. Google Pay"
                required
              />
            </div>
            <div className="grid gap-2">
              <Label>Supported payment methods</Label>
              <p className="text-xs text-muted-foreground">Select all methods this app can use. You can add sources per method later.</p>
              <div className="grid grid-cols-2 gap-2 pt-1">
                {methodsLoading ? (
                  <p className="text-sm text-muted-foreground col-span-2">Loading methods…</p>
                ) : (
                  allMethods.map((method) => (
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
                  ))
                )}
              </div>
            </div>
            <div className="flex gap-3 pt-2">
              <Button type="submit" disabled={submitting}>
                {submitting ? "Creating…" : "Create app"}
              </Button>
              <Button type="button" variant="outline" asChild>
                <Link href="/dashboard/apps">Cancel</Link>
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
