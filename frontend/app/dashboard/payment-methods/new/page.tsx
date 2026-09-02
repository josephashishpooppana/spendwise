"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeft, ChevronDown } from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Checkbox } from "@/components/ui/checkbox";
import * as paymentMethodsApi from "@/lib/api/payment-methods";
import type { SourceTypeOption } from "@/lib/api/payment-methods";

export default function NewPaymentMethodPage() {
  const router = useRouter();
  const [sourceTypes, setSourceTypes] = useState<SourceTypeOption[]>([]);
  const [loadingTypes, setLoadingTypes] = useState(true);
  const [name, setName] = useState("");
  const [selectedKeys, setSelectedKeys] = useState<string[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [popoverOpen, setPopoverOpen] = useState(false);

  useEffect(() => {
    let cancelled = false;
    paymentMethodsApi.getSourceTypes().then((res) => {
      if (cancelled) return;
      setLoadingTypes(false);
      if (res.success && res.data) {
        setSourceTypes(res.data);
      } else {
        toast.error("Failed to load source types");
      }
    });
    return () => {
      cancelled = true;
    };
  }, []);

  function toggleSourceType(key: string) {
    setSelectedKeys((prev) =>
      prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key]
    );
  }

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    const trimmedName = name.trim();
    if (!trimmedName) {
      toast.error("Display name is required");
      return;
    }
    if (selectedKeys.length === 0) {
      toast.error("Select at least one payment source type");
      return;
    }
    setSubmitting(true);
    try {
      const res = await paymentMethodsApi.createPaymentMethod({
        name: trimmedName,
        sourceTypeKeys: selectedKeys,
      });
      if (res.success && res.data) {
        toast.success("Payment method created");
        router.push(`/dashboard/payment-methods/${res.data.id}`);
      } else {
        toast.error(res.message || "Failed to create payment method");
      }
    } catch {
      toast.error("Something went wrong");
    } finally {
      setSubmitting(false);
    }
  }

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
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Add payment method</h1>
          <p className="text-sm text-muted-foreground">
            Create a custom payment method. Enter a display name and select which payment source types it supports.
          </p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Method details</CardTitle>
          <CardDescription>Display name and payment source types</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={onSubmit} className="flex flex-col gap-5">
            <div className="grid gap-2">
              <Label htmlFor="name">Display name</Label>
              <Input
                id="name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. NEFT, IMPS, Custom Card"
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
                      <p className="text-sm text-muted-foreground px-2 py-2">No source types found. Add them in Django admin.</p>
                    )}
                  </div>
                </PopoverContent>
              </Popover>
              <p className="text-xs text-muted-foreground">Select at least one type. Options are loaded from the database.</p>
            </div>
            <div className="flex gap-3 pt-2">
              <Button type="submit" disabled={submitting || loadingTypes}>
                {submitting ? "Creating…" : "Create"}
              </Button>
              <Button type="button" variant="outline" asChild>
                <Link href="/dashboard/payment-methods">Cancel</Link>
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
