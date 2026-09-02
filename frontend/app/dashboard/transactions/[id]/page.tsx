"use client";

import { useState, useEffect, useMemo } from "react";
import Link from "next/link";
import { useRouter, useParams, useSearchParams } from "next/navigation";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { format } from "date-fns";
import { toast } from "sonner";
import {
  ArrowLeft,
  ArrowDownLeft,
  ArrowUpRight,
  Loader2,
  Pencil,
  CalendarIcon,
} from "lucide-react";
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
import { formatCurrency, formatDate, getCategoryLabel, getMethodLabel } from "@/lib/format";
import * as transactionsApi from "@/lib/api/transactions";
import * as paymentMethodsApi from "@/lib/api/payment-methods";
import { normalizePaymentMethods, normalizePaymentSources } from "@/lib/normalize-payments";
import type { Transaction, TransactionType, TransactionCategory, CashbackKind, CashbackRecord } from "@/lib/types";
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

function toFormValues(t: Transaction): FormValues {
  const type = (t.type?.toLowerCase() || "expense") as TransactionType;
  return {
    type,
    amount: t.amount ?? 0,
    category: (t.category as TransactionCategory) || (type === "income" ? "salary" : "other"),
    description: t.description || "",
    date: t.date ? new Date(t.date) : new Date(),
    paymentAppId: t.paymentAppId && t.paymentAppId !== "null" ? t.paymentAppId : "none",
    paymentMethodId: t.paymentMethodId || "",
    paymentSourceId: t.paymentSourceId || "",
    notes: t.notes || "",
  };
}

export default function TransactionDetailPage() {
  const router = useRouter();
  const params = useParams();
  const searchParams = useSearchParams();
  const id = typeof params?.id === "string" ? params.id : "";
  const isEdit = searchParams.get("edit") === "1";

  const [transaction, setTransaction] = useState<Transaction | null>(null);
  const [loading, setLoading] = useState(true);
  const [notFound, setNotFound] = useState(false);
  const [paymentApps, setPaymentApps] = useState<PaymentApp[]>([]);
  const [paymentMethods, setPaymentMethods] = useState<PaymentMethod[]>([]);
  const [paymentSources, setPaymentSources] = useState<PaymentSource[]>([]);
  const [editFormReady, setEditFormReady] = useState(false);
  const [cashbackEnabled, setCashbackEnabled] = useState(false);
  const [cashbackKind, setCashbackKind] = useState<CashbackKind>("fixed");
  const [cashbackAmount, setCashbackAmount] = useState(0);
  const [cashbackPercentage, setCashbackPercentage] = useState(0);
  const [cashbackRewardPoints, setCashbackRewardPoints] = useState(0);
  const [cashbackCreditSourceId, setCashbackCreditSourceId] = useState<string>("same");
  const [cashbackRewardAppId, setCashbackRewardAppId] = useState<string>("");
  const [rewardPointsEnabled, setRewardPointsEnabled] = useState(false);

  const txnType = transaction?.type?.toLowerCase() as TransactionType | undefined;

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    reset,
    getValues,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: (values, context, options) =>
      zodResolver(buildSchema((values.type || "expense") as TransactionType))(
        values,
        context,
        options
      ),
    defaultValues: {
      type: "expense",
      amount: 0,
      category: "other",
      description: "",
      date: new Date(),
      paymentAppId: "none",
      paymentMethodId: "",
      paymentSourceId: "",
      notes: "",
    },
  });

  const selectedAppId = watch("paymentAppId");
  const selectedMethodId = watch("paymentMethodId");
  const selectedMethod = paymentMethods.find((m) => m.id === selectedMethodId);
  const activePaymentSources = useMemo(
    () => paymentSources.filter((p) => p.isActive),
    [paymentSources]
  );
  const watchedDate = watch("date");
  const formType = watch("type");
  const categories =
    (isEdit && editFormReady ? formType : txnType) === "income"
      ? INCOME_CATEGORIES
      : EXPENSE_CATEGORIES;

  // Fetch transaction
  useEffect(() => {
    if (!id) {
      setLoading(false);
      setNotFound(true);
      return;
    }
    let cancelled = false;
    setLoading(true);
    setNotFound(false);
    transactionsApi.getTransaction(id).then((res) => {
      if (cancelled) return;
      if (res.success && res.data) {
        setTransaction(res.data);
      } else {
        setNotFound(true);
        setTransaction(null);
      }
      setLoading(false);
    });
    return () => {
      cancelled = true;
    };
  }, [id]);

  // When in edit mode: load apps, then methods/sources from transaction (or all sources for income), then set form
  useEffect(() => {
    if (!isEdit || !transaction) return;
    let cancelled = false;
    const isIncomeTxn = (transaction.type?.toLowerCase() || "") === "income";
    const appId =
      transaction.paymentAppId && transaction.paymentAppId !== "null"
        ? transaction.paymentAppId
        : null;
    const methodType = transaction.paymentMethodType || "other";

    Promise.all([
      paymentMethodsApi.getPaymentApps(),
      isIncomeTxn
        ? paymentMethodsApi.getPaymentSources({})
        : paymentMethodsApi.getPaymentMethods({ appId: appId ?? undefined }),
    ]).then(([appsRes, secondRes]) => {
      if (cancelled) return;
      if (appsRes.success && appsRes.data) {
        setPaymentApps(appsRes.data);
      }
      if (isIncomeTxn) {
        const sourcesRes = secondRes as Awaited<ReturnType<typeof paymentMethodsApi.getPaymentSources>>;
        if (sourcesRes.success && sourcesRes.data) {
          setPaymentSources(normalizePaymentSources(sourcesRes.data));
        }
        reset(toFormValues(transaction));
        setEditFormReady(true);
        return;
      }
      const methodsRes = secondRes as Awaited<ReturnType<typeof paymentMethodsApi.getPaymentMethods>>;
      if (methodsRes.success && methodsRes.data) {
        const methods = normalizePaymentMethods(methodsRes.data);
        setPaymentMethods(methods);
        paymentMethodsApi
          .getPaymentSources({
            appId: appId ?? undefined,
            method: methodType,
          })
          .then((sourcesRes) => {
            if (cancelled) return;
            if (sourcesRes.success && sourcesRes.data) {
              setPaymentSources(normalizePaymentSources(sourcesRes.data));
            }
            reset(toFormValues(transaction));
            setEditFormReady(true);
          });
      } else {
        reset(toFormValues(transaction));
        setEditFormReady(true);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [isEdit, transaction?.id]);

  // When app changes in edit form (expense only): load methods
  useEffect(() => {
    if (!isEdit || formType !== "expense" || selectedAppId === undefined || selectedAppId === "") return;
    const appId = selectedAppId === "none" ? null : selectedAppId;
    paymentMethodsApi.getPaymentMethods({ appId: appId ?? undefined }).then((res) => {
      if (res.success && res.data) {
        const list = normalizePaymentMethods(res.data);
        setPaymentMethods(list);
        const current = getValues("paymentMethodId");
        if (!list.some((m) => m.id === current)) {
          setValue("paymentMethodId", list[0]?.id ?? "");
        }
      }
    });
  }, [isEdit, formType, selectedAppId, setValue, getValues]);

  useEffect(() => {
    if (!isEdit || formType !== "expense" || !selectedMethodId || !selectedMethod?.type) {
      if (isEdit && formType === "expense" && !selectedMethodId) setPaymentSources([]);
      return;
    }
    const appId = selectedAppId === "none" ? null : selectedAppId;
    paymentMethodsApi
      .getPaymentSources({
        appId: appId ?? undefined,
        method: selectedMethod.type,
      })
      .then((res) => {
        if (res.success && res.data) {
          const list = normalizePaymentSources(res.data);
          setPaymentSources(list);
          const current = getValues("paymentSourceId");
          if (!list.some((s) => s.id === current)) {
            setValue("paymentSourceId", list[0]?.id ?? "");
          }
        }
      });
  }, [isEdit, formType, selectedAppId, selectedMethodId, selectedMethod?.type, setValue, getValues]);

  // When switching to income in edit: load all sources for "Credited to"
  useEffect(() => {
    if (!isEdit || formType !== "income") return;
    paymentMethodsApi.getPaymentSources({}).then((res) => {
      if (res.success && res.data) {
        setPaymentSources(normalizePaymentSources(res.data));
        const current = getValues("paymentSourceId");
        const list = normalizePaymentSources(res.data);
        if (current && !list.some((s) => s.id === current)) {
          setValue("paymentSourceId", list[0]?.id ?? "");
        }
      }
    });
  }, [isEdit, formType, setValue, getValues]);

  // Populate cashback state when editing an expense that has cashback
  useEffect(() => {
    if (!isEdit || !transaction || (transaction.type?.toLowerCase() || "") !== "expense") return;
    const cb = transaction.cashback;
    const list = Array.isArray(cb) ? cb : cb && typeof cb === "object" && "kind" in cb ? [cb as CashbackRecord] : [];
    const cashbackEntry = list.find((e) => e.kind === "fixed" || e.kind === "percentage");
    const rewardEntry = list.find((e) => e.kind === "reward_points");
    if (cashbackEntry) {
      const r = cashbackEntry as CashbackRecord;
      setCashbackEnabled(true);
      setCashbackKind((r.kind as CashbackKind) || "fixed");
      setCashbackAmount(typeof r.amount === "number" ? r.amount : 0);
      setCashbackPercentage(typeof r.percentage === "number" ? r.percentage : 0);
      setCashbackCreditSourceId(r.creditSourceId && r.creditSourceId !== transaction.paymentSourceId ? r.creditSourceId : "same");
    } else {
      setCashbackEnabled(false);
      setCashbackKind("fixed");
      setCashbackAmount(0);
      setCashbackPercentage(0);
      setCashbackCreditSourceId("same");
    }
    if (rewardEntry) {
      const r = rewardEntry as CashbackRecord;
      setRewardPointsEnabled(true);
      setCashbackRewardPoints(typeof r.rewardPoints === "number" ? r.rewardPoints : 0);
      setCashbackRewardAppId(r.rewardAppId || "");
    } else {
      setRewardPointsEnabled(false);
      setCashbackRewardPoints(0);
      setCashbackRewardAppId("");
    }
  }, [isEdit, transaction?.id, transaction?.type, transaction?.paymentSourceId, transaction?.cashback]);

  async function onSubmit(data: FormValues) {
    if (!id) return;
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
    const paymentAppId =
      data.paymentAppId && data.paymentAppId !== "none" ? data.paymentAppId : undefined;
    try {
      const payload: Parameters<typeof transactionsApi.updateTransaction>[1] = {
        type: data.type,
        amount: data.amount,
        category: data.category as TransactionCategory,
        description: data.description,
        date: data.date.toISOString(),
        notes: data.notes || undefined,
      };
      if (isIncome) {
        payload.paymentAppId = undefined;
        payload.paymentMethodId = "";
        payload.paymentSourceId = data.paymentSourceId;
      } else {
        const method = paymentMethods.find((p) => p.id === data.paymentMethodId)!;
        const source = activePaymentSources.find((p) => p.id === data.paymentSourceId)!;
        payload.paymentMethodId = method.id;
        payload.paymentSourceId = source.id;
        payload.paymentAppId = paymentAppId;
        if (cashbackEnabled || rewardPointsEnabled) {
          if (rewardPointsEnabled && !cashbackRewardAppId) {
            toast.error("Select an app for reward points.");
            return;
          }
          const entries: Array<Record<string, unknown>> = [];
          if (cashbackEnabled) {
            const creditSourceId = cashbackCreditSourceId === "same" ? source.id : cashbackCreditSourceId;
          if (cashbackKind === "fixed") {
            entries.push({ kind: "fixed", amount: cashbackAmount, creditSourceId });
          } else {
            entries.push({ kind: "percentage", percentage: cashbackPercentage, creditSourceId });
          }
          }
          if (rewardPointsEnabled && cashbackRewardAppId) {
            entries.push({ kind: "reward_points", rewardPoints: cashbackRewardPoints, rewardAppId: cashbackRewardAppId });
          }
          (payload as Record<string, unknown>).cashback = { entries };
        } else {
          (payload as Record<string, unknown>).cashback = { entries: [] };
        }
      }
      const res = await transactionsApi.updateTransaction(id, payload);
      if (res.success && res.data) {
        setTransaction(res.data);
        toast.success("Transaction updated.");
        router.replace(`/dashboard/transactions/${id}`);
      } else {
        toast.error(res.message || "Failed to update.");
      }
    } catch {
      toast.error("Something went wrong. Try again.");
    }
  }

  if (loading) {
    return (
      <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-2xl mx-auto">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="icon" asChild>
            <Link href="/dashboard/transactions">
              <ArrowLeft className="h-4 w-4" />
              <span className="sr-only">Back</span>
            </Link>
          </Button>
        </div>
        <div className="flex items-center justify-center py-16">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      </div>
    );
  }

  if (notFound || !transaction) {
    return (
      <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-2xl mx-auto">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/dashboard/transactions">
            <ArrowLeft className="h-4 w-4" />
            <span className="sr-only">Back</span>
          </Link>
        </Button>
        <Card>
          <CardContent className="pt-6">
            <p className="text-muted-foreground">Transaction not found.</p>
            <Button asChild className="mt-4">
              <Link href="/dashboard/transactions">Back to transactions</Link>
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  const type = (transaction.type?.toLowerCase() || "expense") as TransactionType;
  const isIncome = type === "income";

  if (isEdit && editFormReady) {
    return (
      <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-2xl mx-auto">
        <div className="flex items-center gap-3">
          <Button variant="ghost" size="icon" asChild>
            <Link href={`/dashboard/transactions/${id}`}>
              <ArrowLeft className="h-4 w-4" />
              <span className="sr-only">Back</span>
            </Link>
          </Button>
        </div>
        <div>
          <h1 className="text-xl font-semibold tracking-tight">Edit Transaction</h1>
          <p className="text-sm text-muted-foreground">
            Update income or expense
          </p>
        </div>
        <Card>
          <CardHeader className="pb-4">
            <CardTitle className="text-base">Type</CardTitle>
            <Tabs
              value={watch("type")}
              onValueChange={(v) => {
                const t = v as TransactionType;
                setValue("type", t);
                setValue("category", t === "income" ? "salary" : "other");
                if (t === "income") {
                  setValue("paymentAppId", "none");
                  setValue("paymentMethodId", "");
                  setValue("paymentSourceId", "");
                }
              } }
            >
              <TabsList className="grid w-full grid-cols-2 h-11">
                <TabsTrigger
                  value="income"
                  className="data-[state=active]:bg-income/15 data-[state=active]:text-income"
                >
                  <ArrowDownLeft className="mr-1.5 h-4 w-4" />
                  Income
                </TabsTrigger>
                <TabsTrigger
                  value="expense"
                  className="data-[state=active]:bg-expense/15 data-[state=active]:text-expense"
                >
                  <ArrowUpRight className="mr-1.5 h-4 w-4" />
                  Expense
                </TabsTrigger>
              </TabsList>
            </Tabs>
          </CardHeader>
        </Card><Card>
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
                  {...register("amount")}
                  aria-invalid={!!errors.amount}
                  className={cn(errors.amount && "border-destructive")} />
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
                  className={cn(errors.description && "border-destructive")} />
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
                      initialFocus />
                  </PopoverContent>
                </Popover>
              </div>

              {formType === "income" && (
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
                      {activePaymentSources.map((ps) => (
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

              {formType === "expense" && (
                <>
              <div className="grid gap-2">
                <Label>Payment app</Label>
                <Select
                  value={watch("paymentAppId") || "none"}
                  onValueChange={(v) => setValue("paymentAppId", v)}
                >
                  <SelectTrigger className="w-full">
                    <SelectValue placeholder="e.g. Google Pay, PhonePe" />
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

              <div className="grid gap-2">
                <Label>Payment method</Label>
                <Select
                  value={watch("paymentMethodId")}
                  onValueChange={(v) => setValue("paymentMethodId", v)}
                >
                  <SelectTrigger className="w-full" aria-invalid={!!errors.paymentMethodId}>
                    <SelectValue placeholder="Select method" />
                  </SelectTrigger>
                  <SelectContent>
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
                  <SelectContent>
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
                  <Switch checked={cashbackEnabled} onCheckedChange={setCashbackEnabled} />
                </div>
                {cashbackEnabled && (
                  <div className="grid gap-4 pt-2">
                    <div className="grid gap-2">
                      <Label>Type</Label>
                      <Select value={cashbackKind} onValueChange={(v) => setCashbackKind(v as "fixed" | "percentage")}>
                        <SelectTrigger className="w-full"><SelectValue /></SelectTrigger>
                        <SelectContent>
                          <SelectItem value="fixed">Fixed amount (₹)</SelectItem>
                          <SelectItem value="percentage">Percentage of expense</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                    {cashbackKind === "fixed" && (
                      <div className="grid gap-2">
                        <Label>Cashback amount (₹)</Label>
                        <Input type="number" min={0} step={1} value={cashbackAmount || ""} onChange={(e) => setCashbackAmount(Number(e.target.value) || 0)} placeholder="0" />
                      </div>
                    )}
                    {cashbackKind === "percentage" && (
                      <div className="grid gap-2">
                        <Label>Percentage (%)</Label>
                        <Input type="number" min={0} max={100} step={0.5} value={cashbackPercentage || ""} onChange={(e) => setCashbackPercentage(Number(e.target.value) || 0)} placeholder="e.g. 5" />
                        {watch("amount") > 0 && cashbackPercentage > 0 && (
                          <p className="text-xs text-muted-foreground">≈ ₹{Math.round((watch("amount") * cashbackPercentage) / 100)}</p>
                        )}
                      </div>
                    )}
                    <div className="grid gap-2">
                      <Label>Credit to</Label>
                      <Select value={cashbackCreditSourceId} onValueChange={setCashbackCreditSourceId}>
                        <SelectTrigger className="w-full"><SelectValue placeholder="Same or different source" /></SelectTrigger>
                        <SelectContent>
                          <SelectItem value="same">Same source (expense account)</SelectItem>
                          {activePaymentSources.map((ps) => (
                            <SelectItem key={ps.id} value={ps.id}>{ps.name}</SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <p className="text-xs text-muted-foreground">Cashback will show as income in history</p>
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
                  <Switch checked={rewardPointsEnabled} onCheckedChange={setRewardPointsEnabled} />
                </div>
                {rewardPointsEnabled && (
                  <div className="grid gap-4 pt-2">
                    <div className="grid gap-2">
                      <Label>Reward points</Label>
                      <Input type="number" min={0} step={1} value={cashbackRewardPoints || ""} onChange={(e) => setCashbackRewardPoints(Number(e.target.value) || 0)} placeholder="0" />
                    </div>
                    <div className="grid gap-2">
                      <Label>App (used for expense)</Label>
                      <Select value={cashbackRewardAppId || "none"} onValueChange={(v) => setCashbackRewardAppId(v === "none" ? "" : v)}>
                        <SelectTrigger className="w-full"><SelectValue placeholder="Select app" /></SelectTrigger>
                        <SelectContent>
                          <SelectItem value="none"><span className="text-muted-foreground">None</span></SelectItem>
                          {paymentApps.map((app) => (
                            <SelectItem key={app.id} value={app.id}>{app.name}</SelectItem>
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
                  className="resize-none" />
              </div>

              <div className="flex gap-3 pt-2">
                <Button type="submit" className="flex-1" disabled={isSubmitting}>
                  {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
                  Save changes
                </Button>
                <Button type="button" variant="outline" asChild>
                  <Link href={`/dashboard/transactions/${id}`}>Cancel</Link>
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>
      </div>
    );
  }

  // View mode
  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8 max-w-2xl mx-auto">
      <div className="flex items-center gap-3 flex-wrap">
        <Button variant="ghost" size="icon" asChild>
          <Link href="/dashboard/transactions">
            <ArrowLeft className="h-4 w-4" />
            <span className="sr-only">Back</span>
          </Link>
        </Button>
        <div className="flex-1 min-w-0">
          <h1 className="text-xl font-semibold tracking-tight">Transaction</h1>
          <p className="text-sm text-muted-foreground">
            {isIncome ? "Income" : "Expense"} · {formatDate(transaction.date || transaction.createdAt, "long")}
          </p>
        </div>
        <Button asChild size="sm" variant="outline">
          <Link href={`/dashboard/transactions/${id}?edit=1`}>
            <Pencil className="mr-1.5 h-4 w-4" />
            Edit
          </Link>
        </Button>
      </div>

      <Card>
        <CardContent className="pt-6 space-y-6">
          <div className="flex items-center justify-between">
            <span className="text-sm text-muted-foreground">Amount</span>
            <span
              className={cn(
                "text-xl font-semibold",
                isIncome ? "text-income" : "text-expense"
              )}
            >
              {isIncome ? "+" : "-"}
              {formatCurrency(transaction.amount)}
            </span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-sm text-muted-foreground">Type</span>
            <span className="capitalize">{type}</span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-sm text-muted-foreground">Category</span>
            <span>{getCategoryLabel(transaction.category || "other")}</span>
          </div>
          {transaction.description ? (
            <div className="flex flex-col gap-1">
              <span className="text-sm text-muted-foreground">Description</span>
              <span>{transaction.description}</span>
            </div>
          ) : null}
          <div className="flex items-center justify-between">
            <span className="text-sm text-muted-foreground">Date</span>
            <span>{formatDate(transaction.date || transaction.createdAt, "long")}</span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-sm text-muted-foreground">Payment method</span>
            <span>
              {getMethodLabel(transaction.paymentMethodType || "other")} · {transaction.paymentSourceName || "—"}
            </span>
          </div>
          {transaction.paymentAppName ? (
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted-foreground">App</span>
              <span>{transaction.paymentAppName}</span>
            </div>
          ) : null}
          {!isIncome && (() => {
            const cb = transaction.cashback;
            const list = Array.isArray(cb) ? cb : cb && typeof cb === "object" && "amount" in cb ? [cb] : [];
            const totalAmount = list.reduce((sum, e) => sum + (typeof (e as { amount?: number }).amount === "number" ? (e as { amount: number }).amount : 0), 0);
            const legacyAmount = (transaction as { cashbackReceived?: number }).cashbackReceived ?? totalAmount;
            const displayAmount = totalAmount > 0 ? totalAmount : legacyAmount;
            return displayAmount ? (
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Cashback</span>
                <span className="text-income">
                  +{formatCurrency(displayAmount)}
                </span>
              </div>
            ) : null;
          })()}
          {!isIncome && transaction.cashback && Array.isArray(transaction.cashback) && transaction.cashback.length > 0 && (
            <div className="flex flex-col gap-2 rounded-lg border p-3 bg-muted/30">
              <span className="text-sm font-medium text-muted-foreground">Cashback details</span>
              {(transaction.cashback as CashbackRecord[]).map((entry, i) => (
                <div key={entry.id || i} className="text-sm">
                  {entry.kind === "reward_points" ? (
                    <>Reward points: {entry.rewardPoints ?? "—"} {entry.rewardAppName ? `(${entry.rewardAppName})` : ""}</>
                  ) : (
                    <>Credited to: {entry.creditSourceName ?? "—"} {entry.percentage != null ? `(${entry.percentage}%)` : ""}</>
                  )}
                </div>
              ))}
            </div>
          )}
          {!isIncome && transaction.cashback && !Array.isArray(transaction.cashback) && typeof transaction.cashback === "object" && "kind" in transaction.cashback && (
            <div className="flex flex-col gap-1 rounded-lg border p-3 bg-muted/30">
              <span className="text-sm font-medium text-muted-foreground">Cashback details</span>
              <span className="text-sm">{(transaction.cashback as CashbackRecord).kind === "reward_points" ? `Reward points: ${(transaction.cashback as CashbackRecord).rewardPoints ?? "—"}` : `Credited to: ${(transaction.cashback as CashbackRecord).creditSourceName ?? "—"}`}</span>
            </div>
          )}
          {isIncome && (transaction as { cashbackFromDescription?: string }).cashbackFromDescription && (
            <div className="flex flex-col gap-1">
              <span className="text-sm text-muted-foreground">Cashback from expense</span>
              <span className="text-sm">{(transaction as { cashbackFromDescription?: string }).cashbackFromDescription}</span>
            </div>
          )}
          {transaction.notes ? (
            <div className="flex flex-col gap-1">
              <span className="text-sm text-muted-foreground">Notes</span>
              <p className="text-sm whitespace-pre-wrap">{transaction.notes}</p>
            </div>
          ) : null}
        </CardContent>
      </Card>
    </div>
  );
}
