"use client";

import { useState, useEffect, useCallback } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import {
  ArrowDownLeft,
  ArrowUpRight,
  Plus,
  ScanLine,
  Search,
  MoreHorizontal,
  Pencil,
  Trash2,
  Eye,
  ChevronLeft,
  ChevronRight,
  Filter,
  X,
} from "lucide-react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
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
import { formatCurrency, formatDate, getCategoryLabel, getMethodLabel } from "@/lib/format";
import * as transactionsApi from "@/lib/api/transactions";
import * as paymentMethodsApi from "@/lib/api/payment-methods";
import { normalizePaymentMethods, normalizePaymentSources } from "@/lib/normalize-payments";
import type {
  Transaction,
  TransactionType,
  TransactionCategory,
  PaymentMethodType,
  PaymentMethod,
  PaymentSource,
} from "@/lib/types";
import { cn } from "@/lib/utils";

const TYPE_TABS: { value: "" | TransactionType; label: string }[] = [
  { value: "", label: "All" },
  { value: "income", label: "Income" },
  { value: "expense", label: "Expense" },
];

const SORT_OPTIONS = [
  { value: "date_desc", label: "Date (newest)" },
  { value: "date_asc", label: "Date (oldest)" },
  { value: "amount_desc", label: "Amount (high → low)" },
  { value: "amount_asc", label: "Amount (low → high)" },
] as const;

const LIMIT = 20;

export default function TransactionsPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [paymentMethods, setPaymentMethods] = useState<PaymentMethod[]>([]);
  const [paymentSources, setPaymentSources] = useState<PaymentSource[]>([]);
  const [loading, setLoading] = useState(true);
  const [total, setTotal] = useState(0);
  const [showFilters, setShowFilters] = useState(false);
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const [deleting, setDeleting] = useState(false);

  const typeParam = searchParams.get("type") ?? "";
  const type: "" | TransactionType =
    typeParam === "income" || typeParam === "expense" ? typeParam : "";
  const category = searchParams.get("category") || "";
  const search = searchParams.get("search") || "";
  const dateFrom = searchParams.get("dateFrom") || "";
  const dateTo = searchParams.get("dateTo") || "";
  const paymentMethodType = searchParams.get("paymentMethodType") || "";
  const paymentSourceId = searchParams.get("paymentSourceId") || "";
  const sort = (searchParams.get("sort") || "date_desc") as (typeof SORT_OPTIONS)[number]["value"];
  const page = Math.max(1, parseInt(searchParams.get("page") || "1", 10));

  const updateParams = useCallback(
    (updates: Record<string, string | number | undefined>) => {
      const next = new URLSearchParams(searchParams.toString());
      Object.entries(updates).forEach(([key, value]) => {
        if (value === undefined || value === "") next.delete(key);
        else next.set(key, String(value));
      });
      next.delete("page"); // reset page when filters change except when we set page explicitly
      if ("page" in updates && updates.page !== undefined) next.set("page", String(updates.page));
      router.push(`/dashboard/transactions?${next.toString()}`);
    },
    [router, searchParams]
  );

  const setPage = (p: number) => {
    const next = new URLSearchParams(searchParams.toString());
    next.set("page", String(p));
    router.push(`/dashboard/transactions?${next.toString()}`);
  };

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    const [sortBy, sortOrder]: [string, "asc" | "desc"] =
      sort === "date_desc" ? ["date", "desc"] : sort === "date_asc" ? ["date", "asc"] : sort === "amount_desc" ? ["amount", "desc"] : ["amount", "asc"];
    const filters = {
      type: type || undefined,
      category: (category || undefined) as TransactionCategory | undefined,
      search: search || undefined,
      dateFrom: dateFrom || undefined,
      dateTo: dateTo || undefined,
      paymentMethodType: (paymentMethodType || undefined) as PaymentMethodType | undefined,
      paymentSourceId: paymentSourceId || undefined,
      sortBy,
      sortOrder,
      page,
      limit: LIMIT,
    };
    transactionsApi.getTransactions(filters).then((res) => {
      if (cancelled) return;
      if (res.success) {
        setTransactions(res.data);
        setTotal(res.pagination?.total ?? res.data.length);
      }
      setLoading(false);
    });
    return () => { cancelled = true; };
  }, [type, category, search, dateFrom, dateTo, paymentMethodType, paymentSourceId, sort, page]);

  useEffect(() => {
    Promise.allSettled([
      paymentMethodsApi.getPaymentMethods(),
      paymentMethodsApi.getPaymentSources(),
    ]).then(([methodsResult, sourcesResult]) => {
      if (methodsResult.status === "fulfilled" && methodsResult.value.success) {
        setPaymentMethods(normalizePaymentMethods(methodsResult.value.data).filter((m) => m.isActive));
      }
      if (sourcesResult.status === "fulfilled" && sourcesResult.value.success) {
        setPaymentSources(normalizePaymentSources(sourcesResult.value.data).filter((s) => s.isActive));
      }
    });
  }, []);

  const totalPages = Math.ceil(total / LIMIT) || 1;
  const hasFilters = !!type || !!category || !!search || !!dateFrom || !!dateTo || !!paymentMethodType || !!paymentSourceId;

  const clearFilters = () => {
    router.push("/dashboard/transactions");
    setShowFilters(false);
  };

  const handleDelete = async (id: string) => {
    setDeleting(true);
    try {
      const res = await transactionsApi.deleteTransaction(id);
      if (res.success) {
        toast.success("Transaction deleted");
        setTransactions((prev) => prev.filter((t) => t.id !== id));
        setTotal((t) => Math.max(0, t - 1));
        setDeleteId(null);
      } else toast.error(res.message || "Failed to delete");
    } catch {
      toast.error("Failed to delete");
    } finally {
      setDeleting(false);
    }
  };

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8">
      {/* Header */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Transactions</h1>
          <p className="text-sm text-muted-foreground">
            Track income and expenses from UPI, cards, bank transfer, cash and more
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Button asChild size="sm" variant="outline">
            <Link href="/dashboard/transactions/new?type=income">
              <ArrowDownLeft className="mr-1.5 h-4 w-4 text-income" />
              Add Income
            </Link>
          </Button>
          <Button asChild size="sm" variant="outline">
            <Link href="/dashboard/transactions/new?type=expense">
              <ArrowUpRight className="mr-1.5 h-4 w-4 text-expense" />
              Add Expense
            </Link>
          </Button>
          <Button asChild size="sm">
            <Link href="/dashboard/transactions/new?scan=true">
              <ScanLine className="mr-1.5 h-4 w-4" />
              <span className="hidden sm:inline">Scan receipt</span>
              <span className="sm:hidden">Scan</span>
            </Link>
          </Button>
        </div>
      </div>

      {/* Type tabs + Filters */}
      <Card>
        <CardHeader className="pb-3">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <Tabs
              value={type || "all"}
              onValueChange={(v) => updateParams({ type: v === "all" ? "" : v, page: 1 })}
            >
              <TabsList>
                {TYPE_TABS.map((t) => (
                  <TabsTrigger key={t.value || "all"} value={t.value || "all"}>
                    {t.label}
                  </TabsTrigger>
                ))}
              </TabsList>
            </Tabs>
            <div className="flex items-center gap-2">
              <Select value={sort} onValueChange={(v) => updateParams({ sort: v })}>
                <SelectTrigger className="w-[180px]">
                  <SelectValue placeholder="Sort by" />
                </SelectTrigger>
                <SelectContent>
                  {SORT_OPTIONS.map((o) => (
                    <SelectItem key={o.value} value={o.value}>
                      {o.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Button
                variant="outline"
                size="icon"
                onClick={() => setShowFilters(!showFilters)}
                className={cn(hasFilters && "border-primary/50 bg-primary/5")}
              >
                <Filter className="h-4 w-4" />
                <span className="sr-only">Filters</span>
              </Button>
              {hasFilters && (
                <Button variant="ghost" size="sm" onClick={clearFilters}>
                  <X className="h-4 w-4 mr-1" />
                  Clear
                </Button>
              )}
            </div>
          </div>

          {showFilters && (
            <CardContent className="pt-0">
              <div className="grid gap-3 rounded-lg border bg-muted/30 p-4 sm:grid-cols-2 lg:grid-cols-4">
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-muted-foreground">Search</label>
                  <div className="relative">
                    <Search className="absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                    <Input
                      placeholder="Description or category..."
                      value={search}
                      onChange={(e) => updateParams({ search: e.target.value || undefined })}
                      className="pl-8"
                    />
                  </div>
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-muted-foreground">Category</label>
                  <Select
                    value={category || "all"}
                    onValueChange={(v) => updateParams({ category: v === "all" ? "" : v })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="All categories" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All categories</SelectItem>
                      <SelectItem value="groceries">{getCategoryLabel("groceries")}</SelectItem>
                      <SelectItem value="rent">{getCategoryLabel("rent")}</SelectItem>
                      <SelectItem value="utilities">{getCategoryLabel("utilities")}</SelectItem>
                      <SelectItem value="food_dining">{getCategoryLabel("food_dining")}</SelectItem>
                      <SelectItem value="transport">{getCategoryLabel("transport")}</SelectItem>
                      <SelectItem value="entertainment">{getCategoryLabel("entertainment")}</SelectItem>
                      <SelectItem value="shopping">{getCategoryLabel("shopping")}</SelectItem>
                      <SelectItem value="health">{getCategoryLabel("health")}</SelectItem>
                      <SelectItem value="education">{getCategoryLabel("education")}</SelectItem>
                      <SelectItem value="salary">{getCategoryLabel("salary")}</SelectItem>
                      <SelectItem value="freelance">{getCategoryLabel("freelance")}</SelectItem>
                      <SelectItem value="investment_returns">{getCategoryLabel("investment_returns")}</SelectItem>
                      <SelectItem value="refund">{getCategoryLabel("refund")}</SelectItem>
                      <SelectItem value="gift">{getCategoryLabel("gift")}</SelectItem>
                      <SelectItem value="reimbursement">{getCategoryLabel("reimbursement")}</SelectItem>
                      <SelectItem value="subscriptions">{getCategoryLabel("subscriptions")}</SelectItem>
                      <SelectItem value="insurance">{getCategoryLabel("insurance")}</SelectItem>
                      <SelectItem value="travel">{getCategoryLabel("travel")}</SelectItem>
                      <SelectItem value="personal_care">{getCategoryLabel("personal_care")}</SelectItem>
                      <SelectItem value="other">{getCategoryLabel("other")}</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-muted-foreground">Payment method</label>
                  <Select
                    value={paymentMethodType || "all"}
                    onValueChange={(v) => updateParams({ paymentMethodType: v === "all" ? "" : v })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="All methods" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All methods</SelectItem>
                      {paymentMethods.map((pm) => (
                        <SelectItem key={pm.id} value={pm.type}>
                          {pm.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-muted-foreground">Payment source</label>
                  <Select
                    value={paymentSourceId || "all"}
                    onValueChange={(v) => updateParams({ paymentSourceId: v === "all" ? "" : v })}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="All sources" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All sources</SelectItem>
                      {paymentSources.map((ps) => (
                        <SelectItem key={ps.id} value={ps.id}>
                          {ps.name}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-muted-foreground">From date</label>
                  <Input
                    type="date"
                    value={dateFrom}
                    onChange={(e) => updateParams({ dateFrom: e.target.value || undefined })}
                  />
                </div>
                <div className="space-y-1.5">
                  <label className="text-xs font-medium text-muted-foreground">To date</label>
                  <Input
                    type="date"
                    value={dateTo}
                    onChange={(e) => updateParams({ dateTo: e.target.value || undefined })}
                  />
                </div>
              </div>
            </CardContent>
          )}
        </CardHeader>
      </Card>

      {/* List */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-base">All transactions</CardTitle>
          <CardDescription>
            {total === 0 ? "No transactions" : `${total} transaction${total === 1 ? "" : "s"}`}
          </CardDescription>
        </CardHeader>
        <CardContent className="p-0">
          {loading ? (
            <div className="flex flex-col divide-y">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="flex items-center gap-3 px-4 py-4 animate-pulse">
                  <div className="h-10 w-10 rounded-lg bg-muted" />
                  <div className="flex-1 space-y-2">
                    <div className="h-4 w-48 bg-muted rounded" />
                    <div className="h-3 w-32 bg-muted rounded" />
                  </div>
                  <div className="h-5 w-20 bg-muted rounded" />
                </div>
              ))}
            </div>
          ) : transactions.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 px-4 text-center">
              <p className="text-muted-foreground mb-4">
                {hasFilters ? "No transactions match your filters." : "No transactions yet."}
              </p>
              {hasFilters ? (
                <Button variant="outline" onClick={clearFilters}>
                  Clear filters
                </Button>
              ) : (
                <div className="flex gap-2">
                  <Button asChild>
                    <Link href="/dashboard/transactions/new?type=income">Add income</Link>
                  </Button>
                  <Button asChild variant="outline">
                    <Link href="/dashboard/transactions/new?type=expense">Add expense</Link>
                  </Button>
                </div>
              )}
            </div>
          ) : (
            <div className="flex flex-col divide-y">
              {transactions.map((txn) => (
                <div
                  key={txn.id}
                  className="flex items-center gap-3 px-4 py-3 hover:bg-muted/50 transition-colors group"
                >
                  <div
                    className={cn(
                      "flex h-10 w-10 shrink-0 items-center justify-center rounded-lg",
                      txn.type === "income" ? "bg-income/10 text-income" : "bg-expense/10 text-expense"
                    )}
                  >
                    {txn.type === "income" ? (
                      <ArrowDownLeft className="h-5 w-5" />
                    ) : (
                      <ArrowUpRight className="h-5 w-5" />
                    )}
                  </div>
                  <Link
                    href={`/dashboard/transactions/${txn.id}`}
                    className="flex flex-1 min-w-0 gap-2 md:gap-4"
                  >
                    <div className="flex flex-1 flex-col gap-0.5 min-w-0">
                      <span className="text-sm font-medium truncate">{txn.description}</span>
                      <div className="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs text-muted-foreground">
                        <span>{getCategoryLabel(txn.category)}</span>
                        <span>·</span>
                        <span>{getMethodLabel(txn.paymentMethodType)}</span>
                        <span>·</span>
                        <span>{txn.paymentSourceName}</span>
                        {(txn as { cashbackFromDescription?: string }).cashbackFromDescription && (
                          <>
                            <span>·</span>
                            <span>Cashback from: {(txn as { cashbackFromDescription?: string }).cashbackFromDescription}</span>
                          </>
                        )}
                      </div>
                    </div>
                    <div className="flex flex-col items-end gap-0.5 shrink-0">
                      <span
                        className={cn(
                          "text-sm font-semibold",
                          txn.type === "income" ? "text-income" : "text-expense"
                        )}
                      >
                        {txn.type === "income" ? "+" : "-"}
                        {formatCurrency(txn.amount)}
                      </span>
                      <span className="text-xs text-muted-foreground">
                        {formatDate(txn.date, "short")}
                      </span>
                    </div>
                  </Link>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8 shrink-0 opacity-0 group-hover:opacity-100 data-[state=open]:opacity-100"
                        onClick={(e) => e.preventDefault()}
                      >
                        <MoreHorizontal className="h-4 w-4" />
                        <span className="sr-only">Actions</span>
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem asChild>
                        <Link href={`/dashboard/transactions/${txn.id}`}>
                          <Eye className="mr-2 h-4 w-4" />
                          View
                        </Link>
                      </DropdownMenuItem>
                      <DropdownMenuItem asChild>
                        <Link href={`/dashboard/transactions/${txn.id}?edit=1`}>
                          <Pencil className="mr-2 h-4 w-4" />
                          Edit
                        </Link>
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        variant="destructive"
                        onClick={() => setDeleteId(txn.id)}
                      >
                        <Trash2 className="mr-2 h-4 w-4" />
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              ))}
            </div>
          )}

          {!loading && transactions.length > 0 && totalPages > 1 && (
            <div className="flex items-center justify-between border-t px-4 py-3">
              <p className="text-xs text-muted-foreground">
                Page {page} of {totalPages} · {total} total
              </p>
              <div className="flex gap-1">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setPage(page - 1)}
                  disabled={page <= 1}
                >
                  <ChevronLeft className="h-4 w-4" />
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setPage(page + 1)}
                  disabled={page >= totalPages}
                >
                  <ChevronRight className="h-4 w-4" />
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Delete confirmation */}
      <AlertDialog open={!!deleteId} onOpenChange={(open) => !open && setDeleteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete transaction?</AlertDialogTitle>
            <AlertDialogDescription>
              This cannot be undone. The transaction will be removed from your history.
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
