"use client";

import { useState, useEffect, useMemo } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { format } from "date-fns";
import { toast } from "sonner";
import { CalendarIcon, ArrowLeft, ArrowDownLeft, ArrowUpRight, Loader2, ScanLine } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Calendar } from "@/components/ui/calendar";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Switch } from "@/components/ui/switch";
import { getCategoryLabel } from "@/lib/format";
import * as transactionsApi from "@/lib/api/transactions";
import * as paymentMethodsApi from "@/lib/api/payment-methods";
import { normalizePaymentMethods, normalizePaymentSources } from "@/lib/normalize-payments";
import type { TransactionType, TransactionCategory, CashbackKind } from "@/lib/types";
import type { PaymentMethod, PaymentSource, PaymentApp } from "@/lib/types";
import { cn } from "@/lib/utils";

const INCOME_CATEGORIES: TransactionCategory[] = [
  "salary",
  "freelance",
  "investment_returns",
  "refund",
  "gift",
  "reimbursement",
];

const EXPENSE_CATEGORIES: TransactionCategory[] = [
  "groceries",
  "rent",
  "utilities",
  "food_dining",
  "transport",
  "entertainment",
  "shopping",
  "health",
  "education",
  "subscriptions",
  "insurance",
  "travel",
  "personal_care",
  "other",
];

function buildSchema(type: TransactionType) {
  const categories = type === "income" ? INCOME_CATEGORIES : EXPENSE_CATEGORIES;
  const isIncome = type === "income";
  return z.object({
    type: z.enum(["income", "expense"]),
    amount: z.coerce.number().positive("Enter a valid amount"),
    category: z.enum(categories as [string, ...string[]]),
    description: z.string().min(1, "Description is required"),
    date: z.date(),
    paymentAppId: z.string(),
    paymentMethodId: isIncome ? z.string().optional() : z.string().min(1, "Select payment method"),
    paymentSourceId: z.string().min(1, isIncome ? "Select account credited" : "Select payment source"),
    notes: z.string().optional(),
  });
}

type FormValues = z.infer<ReturnType<typeof buildSchema>>;

const defaultValues: FormValues = {
  type: "expense",
  amount: 0,
  category: "other",
  description: "",
  date: new Date(),
  paymentAppId: "none",
  paymentMethodId: "",
  paymentSourceId: "",
  notes: "",
};

export default function NewTransactionPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const typeParam = (searchParams.get("type") === "income" ? "income" : "expense") as TransactionType;
  const showScan = searchParams.get("scan") === "true";

  const [txnType, setTxnType] = useState<TransactionType>(typeParam);
  const [paymentApps, setPaymentApps] = useState<PaymentApp[]>([]);
  const [paymentMethods, setPaymentMethods] = useState<PaymentMethod[]>([]);
  const [paymentSources, setPaymentSources] = useState<PaymentSource[]>([]);
  const [scanning, setScanning] = useState(false);
  const [cashbackEnabled, setCashbackEnabled] = useState(false);
  const [cashbackKind, setCashbackKind] = useState<CashbackKind>("fixed");
  const [cashbackAmount, setCashbackAmount] = useState(0);
  const [cashbackPercentage, setCashbackPercentage] = useState(0);
  const [cashbackRewardPoints, setCashbackRewardPoints] = useState(0);
  const [cashbackCreditSourceId, setCashbackCreditSourceId] = useState<string>("same");
  const [cashbackRewardAppId, setCashbackRewardAppId] = useState<string>("");
  const [rewardPointsEnabled, setRewardPointsEnabled] = useState(false);
  const schema = useMemo(() => buildSchema(txnType), [txnType]);
  const categories = txnType === "income" ? INCOME_CATEGORIES : EXPENSE_CATEGORIES;

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    reset,
    getValues,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      ...defaultValues,
      type: typeParam,
      category: typeParam === "income" ? "salary" : "other",
    },
  });

  const selectedAppId = watch("paymentAppId");
  const selectedMethodId = watch("paymentMethodId");
  const selectedMethod = paymentMethods.find((m) => m.id === selectedMethodId);
  const activePaymentSources = useMemo(() => paymentSources.filter((p) => p.isActive), [paymentSources]);

  const watchedDate = watch("date");

  // Load payment apps on mount
  useEffect(() => {
    async function loadApps() {
      const res = await paymentMethodsApi.getPaymentApps();
      if (res.success && res.data) {
        setPaymentApps(res.data);
      }
    }
    loadApps();
  }, []);

  // When app changes: load methods for that app, then reset method/source and load sources (expense only)
  useEffect(() => {
    if (txnType !== "expense" || selectedAppId === undefined || selectedAppId === "") return;
    async function loadMethods() {
      const appId = selectedAppId === "none" ? null : selectedAppId;
      const res = await paymentMethodsApi.getPaymentMethods({ appId: appId ?? undefined });
      if (res.success && res.data) {
        const list = normalizePaymentMethods(res.data);
        setPaymentMethods(list);
        const first = list[0];
        if (first) {
          setValue("paymentMethodId", first.id);
        } else {
          setValue("paymentMethodId", "");
          setPaymentSources([]);
          setValue("paymentSourceId", "");
        }
      }
    }
    loadMethods();
  }, [txnType, selectedAppId, setValue]);

  // When app + method change: load sources for that app and method (expense only)
  useEffect(() => {
    if (txnType !== "expense") return;
    if (!selectedMethodId || !selectedMethod?.type) {
      setPaymentSources([]);
      setValue("paymentSourceId", "");
      return;
    }
    const methodType = selectedMethod.type;
    async function loadSources() {
      const appId = selectedAppId === "none" ? null : selectedAppId;
      const res = await paymentMethodsApi.getPaymentSources({
        appId: appId ?? undefined,
        method: methodType,
      });
      if (res.success && res.data) {
        const list = normalizePaymentSources(res.data);
        setPaymentSources(list);
        const first = list[0];
        if (first) {
          setValue("paymentSourceId", first.id);
        } else {
          setValue("paymentSourceId", "");
        }
      }
    }
    loadSources();
  }, [txnType, selectedAppId, selectedMethodId, selectedMethod?.type, setValue]);

  // When income: load all payment sources for "Credited to" dropdown
  useEffect(() => {
    if (txnType !== "income") return;
    async function loadAllSources() {
      const res = await paymentMethodsApi.getPaymentSources({});
      if (res.success && res.data) {
        const list = normalizePaymentSources(res.data);
        setPaymentSources(list);
        const first = list[0];
        if (first) {
          setValue("paymentSourceId", first.id);
        } else {
          setValue("paymentSourceId", "");
        }
      }
    }
    loadAllSources();
  }, [txnType, setValue]);

  useEffect(() => {
    setValue("type", txnType);
    setValue("category", txnType === "income" ? "salary" : "other");
  }, [txnType, setValue]);

  async function onScanReceipt(file: File) {
    setScanning(true);
    try {
      const res = await transactionsApi.scanReceipt(file);
      if (res.success && res.data) {
        if (res.data.amount) setValue("amount", res.data.amount);
        if (res.data.description) setValue("description", res.data.description);
        if (res.data.category) setValue("category", res.data.category as TransactionCategory);
        if (res.data.date) setValue("date", new Date(res.data.date));
        toast.success("Receipt scanned. Review and save.");
      }
    } catch {
      toast.error("Scan failed. Try again.");
    } finally {
      setScanning(false);
    }
  }

  async function onSubmit(data: FormValues) {
    const isIncome = data.type === "income";
    if (isIncome) {
      const source = activePaymentSources.find((p) => p.id === data.paymentSourceId);
      if (!source) {
        toast.error("Select the account credited.");
        return;
      }
    } else {
      const method = paymentMethods.find((p) => p.id === data.paymentMethodId);
      const source = activePaymentSources.find((p) => p.id === data.paymentSourceId);
      if (!method || !source) {
        toast.error("Invalid payment method or source.");
        return;
      }
    }
    const paymentAppId = data.paymentAppId && data.paymentAppId !== "none" ? data.paymentAppId : undefined;
    try {
      if (isIncome) {
        const source = activePaymentSources.find((p) => p.id === data.paymentSourceId)!;
        const res = await transactionsApi.createTransaction({
          type: data.type,
          amount: data.amount,
          category: data.category as TransactionCategory,
          description: data.description,
          date: data.date.toISOString(),
          paymentSourceId: source.id,
          paymentSourceName: source.name,
          paymentSourceType: source.type,
          paymentAppId: paymentAppId ?? undefined,
          paymentMethodId: data.paymentMethodId || undefined,
          notes: data.notes || undefined,
        });
        if (res.success) {
          toast.success("Income added.");
          router.push("/dashboard/transactions");
        } else {
          toast.error(res.message || "Failed to save.");
        }
        return;
      }

      const method = paymentMethods.find((p) => p.id === data.paymentMethodId)!;
      const source = activePaymentSources.find((p) => p.id === data.paymentSourceId)!;
      const paymentSourceType = paymentSources.find((p) => p.id === data.paymentSourceId)?.type;
      if (!paymentSourceType) {
        toast.error("Invalid source type.");
        return;
      }
      const isAutomated = method.name === "NACH";
      const paymentAppName = paymentApps.find((p) => p.id === paymentAppId)?.name;
      const         payload: Parameters<typeof transactionsApi.createTransaction>[0] = {
        type: data.type,
        amount: data.amount,
        category: data.category as TransactionCategory,
        description: data.description,
        date: data.date.toISOString(),
        paymentMethodId: method.id,
        paymentMethodName: method.name,
        paymentMethodType: method.type,
        paymentSourceType: paymentSourceType,
        paymentSourceId: source.id,
        paymentSourceName: source.name,
        paymentAppId: paymentAppId ?? undefined,
        paymentAppName: paymentAppName ?? undefined,
        isAutomated: isAutomated,
        notes: data.notes || undefined,
      };
      if (cashbackEnabled || rewardPointsEnabled) {
        if (rewardPointsEnabled && !cashbackRewardAppId) {
          toast.error("Select an app for reward points.");
          return;
        }
        const entries: Array<Record<string, unknown>> = [];
        if (cashbackEnabled) {
          const creditSourceId =
            cashbackCreditSourceId === "same" ? source.id : cashbackCreditSourceId;
          if (cashbackKind === "fixed") {
            entries.push({
              kind: "fixed",
              amount: cashbackAmount,
              creditSourceId,
            });
          } else {
            entries.push({
              kind: "percentage",
              percentage: cashbackPercentage,
              creditSourceId,
            });
          }
        }
        if (rewardPointsEnabled && cashbackRewardAppId) {
          entries.push({
            kind: "reward_points",
            rewardPoints: cashbackRewardPoints,
            rewardAppId: cashbackRewardAppId,
          });
        }
        (payload as Record<string, unknown>).cashback = { entries };
      }
      const res = await transactionsApi.createTransaction(payload);
      if (res.success) {
        toast.success("Expense added.");
        router.push("/dashboard/transactions");
      } else {
        toast.error(res.message || "Failed to save.");
      }
    } catch {
      toast.error("Something went wrong. Try again.");
    }
  }

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-2xl mx-auto">
      <div className="flex items-center gap-3">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/dashboard/transactions">
            <ArrowLeft className="h-4 w-4" />
            <span className="sr-only">Back</span>
          </Link>
        </Button>
        <div>
          <h1 className="text-xl font-semibold tracking-tight">New Transaction</h1>
          <p className="text-sm text-muted-foreground">Add income or expense</p>
        </div>
      </div>

      <Card>
        <CardHeader className="pb-4">
          <CardTitle className="text-base">Type</CardTitle>
          <CardDescription>Choose income or expense</CardDescription>
          <Tabs
            value={txnType}
            onValueChange={(v) => {
              const t = v as TransactionType;
              setTxnType(t);
              reset({
                ...getValues(),
                type: t,
                category: t === "income" ? "salary" : "other",
              });
            }}
          >
            <TabsList className="grid w-full grid-cols-2 h-11">
              <TabsTrigger value="income" className="data-[state=active]:bg-income/15 data-[state=active]:text-income">
                <ArrowDownLeft className="mr-1.5 h-4 w-4" />
                Income
              </TabsTrigger>
              <TabsTrigger value="expense" className="data-[state=active]:bg-expense/15 data-[state=active]:text-expense">
                <ArrowUpRight className="mr-1.5 h-4 w-4" />
                Expense
              </TabsTrigger>
            </TabsList>
          </Tabs>
        </CardHeader>
      </Card>

      {showScan && (
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-base flex items-center gap-2">
              <ScanLine className="h-4 w-4" />
              Scan receipt
            </CardTitle>
            <CardDescription>Upload a receipt image to auto-fill amount and category</CardDescription>
          </CardHeader>
          <CardContent>
            <input
              type="file"
              accept="image/*"
              className="block w-full text-sm text-muted-foreground file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:bg-primary file:text-primary-foreground file:text-sm file:font-medium"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) onScanReceipt(f);
                e.target.value = "";
              }}
              disabled={scanning}
            />
            {scanning && (
              <p className="mt-2 text-sm text-muted-foreground flex items-center gap-2">
                <Loader2 className="h-4 w-4 animate-spin" />
                Scanning…
              </p>
            )}
          </CardContent>
        </Card>
      )}

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Details</CardTitle>
          <CardDescription>Amount, category, and description</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-5">
            <input type="hidden" {...register("type")} />

            <div className="grid gap-2">
              <Label htmlFor="amount">Amount (₹)</Label>
              <Input
                id="amount"
                type="number"
                min={1}
                step={1}
                placeholder="0"
                {...register("amount")}
                aria-invalid={!!errors.amount}
                className={cn(errors.amount && "border-destructive")}
              />
              {errors.amount && (
                <p className="text-sm text-destructive">{errors.amount.message}</p>
              )}
            </div>

            <div className="grid gap-2">
              <Label>Category</Label>
              <Select
                value={watch("category")}
                onValueChange={(v) => setValue("category", v as TransactionCategory)}
              >
                <SelectTrigger className="w-full" aria-invalid={!!errors.category}>
                  <SelectValue placeholder="Select category" />
                </SelectTrigger>
                <SelectContent>
                  {categories.map((cat) => (
                    <SelectItem key={cat} value={cat}>
                      {getCategoryLabel(cat)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {errors.category && (
                <p className="text-sm text-destructive">{errors.category.message}</p>
              )}
            </div>

            <div className="grid gap-2">
              <Label htmlFor="description">Description</Label>
              <Input
                id="description"
                placeholder="e.g. Monthly salary, Groceries"
                {...register("description")}
                aria-invalid={!!errors.description}
                className={cn(errors.description && "border-destructive")}
              />
              {errors.description && (
                <p className="text-sm text-destructive">{errors.description.message}</p>
              )}
            </div>

            <div className="grid gap-2">
              <Label>Date</Label>
              <Popover>
                <PopoverTrigger asChild>
                  <Button
                    variant="outline"
                    className={cn(
                      "w-full justify-start text-left font-normal",
                      !watchedDate && "text-muted-foreground"
                    )}
                  >
                    <CalendarIcon className="mr-2 h-4 w-4" />
                    {watchedDate ? format(watchedDate, "PPP") : "Pick a date"}
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-auto p-0" align="start">
                  <Calendar
                    mode="single"
                    selected={watchedDate}
                    onSelect={(d) => d && setValue("date", d)}
                    initialFocus
                  />
                </PopoverContent>
              </Popover>
            </div>

            {txnType === "income" && (
              <div className="grid gap-2">
                <Label>Credited to</Label>
                <Select
                  value={watch("paymentSourceId")}
                  onValueChange={(v) => setValue("paymentSourceId", v)}
                >
                  <SelectTrigger className="w-full" aria-invalid={!!errors.paymentSourceId}>
                    <SelectValue placeholder="Select account credited" />
                  </SelectTrigger>
                  <SelectContent className="[&_[data-slot=select-item]>span.absolute]:hidden">
                    {activePaymentSources.filter((ps) => ps.type !== "debit_card").map((ps) => (
                      <SelectItem key={ps.id} value={ps.id}>
                        {ps.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                <p className="text-xs text-muted-foreground">Account where this income was received</p>
                {errors.paymentSourceId && (
                  <p className="text-sm text-destructive">{errors.paymentSourceId.message}</p>
                )}
              </div>
            )}

            {txnType === "expense" && (
              <>
            <div className="grid gap-2">
              <Label>Payment app</Label>
              <Select
                value={watch("paymentAppId") || "none"}
                onValueChange={(v) => {
                  setValue("paymentAppId", v);
                }}
              >
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="e.g. Google Pay, PhonePe" />
                </SelectTrigger>
                <SelectContent className="[&_[data-slot=select-item]>span.absolute]:hidden">
                  <SelectItem value="none">
                    <span className="text-muted-foreground">None</span>
                  </SelectItem>
                  {paymentApps.map((app) => (
                    <SelectItem key={app.id} value={app.id}>
                      {app.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <p className="text-xs text-muted-foreground">Choose the app (e.g. Google Pay, PhonePe, bank app) or None</p>
            </div>

            <div className="grid gap-2">
              <Label>Payment method</Label>
              <Select
                value={watch("paymentMethodId")}
                onValueChange={(v) => setValue("paymentMethodId", v)}
              >
                <SelectTrigger className="w-full" aria-invalid={!!errors.paymentMethodId}>
                  <SelectValue placeholder="Select method" />
                </SelectTrigger>
                <SelectContent className="[&_[data-slot=select-item]>span.absolute]:hidden">
                  {paymentMethods.map((pm) => (
                    <SelectItem key={pm.id} value={pm.id}>
                      {pm.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {errors.paymentMethodId && (
                <p className="text-sm text-destructive">{errors.paymentMethodId.message}</p>
              )}
            </div>

            <div className="grid gap-2">
              <Label>Payment source</Label>
              <Select
                value={watch("paymentSourceId")}
                onValueChange={(v) => setValue("paymentSourceId", v)}
              >
                <SelectTrigger className="w-full" aria-invalid={!!errors.paymentSourceId}>
                  <SelectValue placeholder="Select source" />
                </SelectTrigger>
                <SelectContent className="[&_[data-slot=select-item]>span.absolute]:hidden">
                  {activePaymentSources.map((ps) => (
                    <SelectItem key={ps.id} value={ps.id}>
                      {ps.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              {errors.paymentSourceId && (
                <p className="text-sm text-destructive">{errors.paymentSourceId.message}</p>
              )}
            </div>

            <div className="rounded-lg border p-4 space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <Label className="text-base">Cashback (₹ or %)</Label>
                  <p className="text-xs text-muted-foreground">Fixed amount or percentage credited to an account</p>
                </div>
                <Switch
                  checked={cashbackEnabled}
                  onCheckedChange={setCashbackEnabled}
                />
              </div>
              {cashbackEnabled && (
                <div className="grid gap-4 pt-2">
                  <div className="grid gap-2">
                    <Label>Type</Label>
                    <Select
                      value={cashbackKind}
                      onValueChange={(v) => setCashbackKind(v as "fixed" | "percentage")}
                    >
                      <SelectTrigger className="w-full">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="fixed">Fixed amount (₹)</SelectItem>
                        <SelectItem value="percentage">Percentage of expense</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  {cashbackKind === "fixed" && (
                    <div className="grid gap-2">
                      <Label>Cashback amount (₹)</Label>
                      <Input
                        type="number"
                        min={0}
                        step={1}
                        value={cashbackAmount || ""}
                        onChange={(e) => setCashbackAmount(Number(e.target.value) || 0)}
                        placeholder="0"
                      />
                    </div>
                  )}
                  {cashbackKind === "percentage" && (
                    <div className="grid gap-2">
                      <Label>Percentage (%)</Label>
                      <Input
                        type="number"
                        min={0}
                        max={100}
                        step={0.5}
                        value={cashbackPercentage || ""}
                        onChange={(e) => setCashbackPercentage(Number(e.target.value) || 0)}
                        placeholder="e.g. 5"
                      />
                      {watch("amount") > 0 && cashbackPercentage > 0 && (
                        <p className="text-xs text-muted-foreground">
                          ≈ ₹{Math.round((watch("amount") * cashbackPercentage) / 100)}
                        </p>
                      )}
                    </div>
                  )}
                  <div className="grid gap-2">
                    <Label>Credit to</Label>
                    <Select
                      value={cashbackCreditSourceId}
                      onValueChange={setCashbackCreditSourceId}
                    >
                      <SelectTrigger className="w-full">
                        <SelectValue placeholder="Same or different source" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="same">
                          Same source (expense account)
                        </SelectItem>
                        {activePaymentSources.map((ps) => (
                          <SelectItem key={ps.id} value={ps.id}>
                            {ps.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <p className="text-xs text-muted-foreground">
                      Cashback will show as income in history
                    </p>
                  </div>
                </div>
              )}
            </div>

            <div className="rounded-lg border p-4 space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <Label className="text-base">Reward points</Label>
                  <p className="text-xs text-muted-foreground">Points earned in an app used for this expense</p>
                </div>
                <Switch
                  checked={rewardPointsEnabled}
                  onCheckedChange={setRewardPointsEnabled}
                />
              </div>
              {rewardPointsEnabled && (
                <div className="grid gap-4 pt-2">
                  <div className="grid gap-2">
                    <Label>Reward points</Label>
                    <Input
                      type="number"
                      min={0}
                      step={1}
                      value={cashbackRewardPoints || ""}
                      onChange={(e) => setCashbackRewardPoints(Number(e.target.value) || 0)}
                      placeholder="0"
                    />
                  </div>
                  <div className="grid gap-2">
                    <Label>App (used for expense)</Label>
                    <Select
                      value={cashbackRewardAppId || "none"}
                      onValueChange={(v) => setCashbackRewardAppId(v === "none" ? "" : v)}
                    >
                      <SelectTrigger className="w-full">
                        <SelectValue placeholder="Select app" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="none">
                          <span className="text-muted-foreground">None</span>
                        </SelectItem>
                        {paymentApps.map((app) => (
                          <SelectItem key={app.id} value={app.id}>
                            {app.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              )}
            </div>
              </>
            )}

            <div className="grid gap-2">
              <Label htmlFor="notes">Notes (optional)</Label>
              <Textarea
                id="notes"
                placeholder="Any extra notes"
                {...register("notes")}
                rows={2}
                className="resize-none"
              />
            </div>

            <div className="flex gap-3 pt-2">
              <Button type="submit" className="flex-1" disabled={isSubmitting}>
                {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                {txnType === "income" ? "Add income" : "Add expense"}
              </Button>
              <Button type="button" variant="outline" asChild>
                <Link href="/dashboard/transactions">Cancel</Link>
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
