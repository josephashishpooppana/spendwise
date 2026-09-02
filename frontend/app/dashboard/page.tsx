"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import {
  TrendingUp, TrendingDown, Wallet, ArrowDownLeft, ArrowUpRight,
  Gift, Clock, Plus, ScanLine, ArrowRight, CreditCard,
} from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import { StatCard } from "@/components/stat-card"
import { ExpensePieChart } from "@/components/charts/expense-pie-chart"
import { IncomeExpenseBarChart } from "@/components/charts/income-expense-bar-chart"
import { formatCurrency, formatDate, getCategoryLabel, getMethodLabel } from "@/lib/format"
import * as transactionsApi from "@/lib/api/transactions"
import * as analyticsApi from "@/lib/api/analytics"
import * as notificationsApi from "@/lib/api/notifications"
import type { Transaction, AnalyticsOverview, TrendDataPoint, CategoryBreakdown, Notification, PeriodComparison } from "@/lib/types"

export default function DashboardPage() {
  const [overview, setOverview] = useState<AnalyticsOverview | null>(null)
  const [trends, setTrends] = useState<TrendDataPoint[]>([])
  const [categories, setCategories] = useState<CategoryBreakdown[]>([])
  const [recentTxns, setRecentTxns] = useState<Transaction[]>([])
  const [notifications, setNotifications] = useState<Notification[]>([])
  const [comparison, setComparison] = useState<PeriodComparison | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function load() {
      try {
        const [overviewRes, trendsRes, catsRes, txnRes, notifsRes, compRes] = await Promise.all([
          analyticsApi.getAnalyticsOverview(),
          analyticsApi.getTrendData(),
          analyticsApi.getCategoryBreakdowns(),
          transactionsApi.getTransactions({ limit: 8, sortBy: "date", sortOrder: "desc" }),
          notificationsApi.getNotifications(),
          analyticsApi.getPeriodComparison(),
        ])
        if (overviewRes.success) setOverview(overviewRes.data)
        if (trendsRes.success) setTrends(trendsRes.data)
        if (catsRes.success) setCategories(catsRes.data)
        if (txnRes.success) setRecentTxns(txnRes.data)
        if (notifsRes.success) setNotifications(notifsRes.data.filter((n) => !n.isRead).slice(0, 4))
        if (compRes.success) setComparison(compRes.data)
      } catch {
        // fail silently for demo
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  if (loading) return <DashboardSkeleton />

  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8">
      {/* Header */}
      <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight md:text-3xl text-balance">Dashboard</h1>
          <p className="text-sm text-muted-foreground">
            Overview of your finances for {new Date().toLocaleDateString("en-IN", { month: "long", year: "numeric" })}
          </p>
        </div>
        <div className="flex items-center gap-2">
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
              <span className="hidden sm:inline">Scan Receipt</span>
              <span className="sm:hidden">Scan</span>
            </Link>
          </Button>
        </div>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4 lg:gap-4">
        <StatCard
          title="Total Income"
          value={formatCurrency(overview?.totalIncome || 0)}
          icon={ArrowDownLeft}
          trend={comparison ? comparison.incomeChange : undefined}
          trendLabel="vs last month"
          variant="income"
        />
        <StatCard
          title="Total Expenses"
          value={formatCurrency(overview?.totalExpenses || 0)}
          icon={ArrowUpRight}
          trend={comparison ? comparison.expenseChange : undefined}
          trendLabel="vs last month"
          variant="expense"
        />
        <StatCard
          title="Net Savings"
          value={formatCurrency(overview?.netSavings || 0)}
          icon={Wallet}
          trend={comparison ? comparison.savingsChange : undefined}
          trendLabel="vs last month"
          variant="default"
        />
        <StatCard
          title="Cashback Earned"
          value={formatCurrency(overview?.totalCashback || 0)}
          icon={Gift}
          variant="cashback"
        />
      </div>

      {/* Charts Row */}
      <div className="grid gap-4 md:grid-cols-2">
        <IncomeExpenseBarChart data={trends} />
        <ExpensePieChart data={categories} />
      </div>

      {/* Recent Transactions + Upcoming Dues */}
      <div className="grid gap-4 lg:grid-cols-3">
        {/* Recent Transactions */}
        <Card className="lg:col-span-2">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <div>
              <CardTitle className="text-base font-semibold">Recent Transactions</CardTitle>
              <CardDescription className="text-xs">Your latest financial activity</CardDescription>
            </div>
            <Button asChild variant="ghost" size="sm">
              <Link href="/dashboard/transactions">
                View all <ArrowRight className="ml-1 h-3.5 w-3.5" />
              </Link>
            </Button>
          </CardHeader>
          <CardContent className="px-2 md:px-6">
            <div className="flex flex-col divide-y">
              {recentTxns.map((txn) => (
                <Link
                  key={txn.id}
                  href={`/dashboard/transactions/${txn.id}`}
                  className="flex items-center gap-3 px-2 py-3 rounded-lg hover:bg-muted/50 transition-colors"
                >
                  <div className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-lg ${
                    txn.type === "income" ? "bg-income/10 text-income" : "bg-expense/10 text-expense"
                  }`}>
                    {txn.type === "income" ? (
                      <ArrowDownLeft className="h-4 w-4" />
                    ) : (
                      <ArrowUpRight className="h-4 w-4" />
                    )}
                  </div>
                  <div className="flex flex-1 flex-col gap-0.5 min-w-0">
                    <span className="text-sm font-medium truncate">{txn.description}</span>
                    <div className="flex items-center gap-2 text-xs text-muted-foreground">
                      <span>{getCategoryLabel(txn.category)}</span>
                      <span>{"·"}</span>
                      <span>{getMethodLabel(txn.paymentMethodType)}</span>
                    </div>
                  </div>
                  <div className="flex flex-col items-end gap-0.5 shrink-0">
                    <span className={`text-sm font-semibold ${txn.type === "income" ? "text-income" : "text-expense"}`}>
                      {txn.type === "income" ? "+" : "-"}{formatCurrency(txn.amount)}
                    </span>
                    <span className="text-xs text-muted-foreground">{formatDate(txn.date, "short")}</span>
                  </div>
                </Link>
              ))}
              {recentTxns.length === 0 && (
                <div className="py-8 text-center text-sm text-muted-foreground">
                  No transactions yet. Add your first transaction to get started.
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Upcoming Dues / Reminders */}
        <Card>
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <div>
              <CardTitle className="text-base font-semibold">Upcoming Dues</CardTitle>
              <CardDescription className="text-xs">Payments due soon</CardDescription>
            </div>
            <Button asChild variant="ghost" size="sm">
              <Link href="/dashboard/notifications">
                View all <ArrowRight className="ml-1 h-3.5 w-3.5" />
              </Link>
            </Button>
          </CardHeader>
          <CardContent>
            <div className="flex flex-col gap-3">
              {notifications.map((n) => (
                <div key={n.id} className="flex items-start gap-3 rounded-lg border p-3">
                  <div className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-lg ${
                    n.type === "credit_card_due" ? "bg-expense/10 text-expense" :
                    n.type === "bill_due" ? "bg-pending/10 text-pending" :
                    n.type === "split_settlement" ? "bg-primary/10 text-primary" :
                    "bg-muted text-muted-foreground"
                  }`}>
                    {n.type === "credit_card_due" ? <CreditCard className="h-4 w-4" /> : <Clock className="h-4 w-4" />}
                  </div>
                  <div className="flex flex-col gap-0.5 min-w-0">
                    <span className="text-sm font-medium">{n.title}</span>
                    <span className="text-xs text-muted-foreground line-clamp-2">{n.message}</span>
                    {n.dueDate && (
                      <Badge variant="outline" className="mt-1 w-fit text-[10px]">
                        Due {formatDate(n.dueDate, "short")}
                      </Badge>
                    )}
                  </div>
                </div>
              ))}
              {notifications.length === 0 && (
                <div className="py-6 text-center text-sm text-muted-foreground">
                  No upcoming dues. You are all caught up!
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Quick Actions - Mobile */}
      <div className="fixed bottom-20 right-4 z-40 md:hidden">
        <Button asChild size="icon" className="h-14 w-14 rounded-full shadow-lg">
          <Link href="/dashboard/transactions/new">
            <Plus className="h-6 w-6" />
            <span className="sr-only">Add Transaction</span>
          </Link>
        </Button>
      </div>
    </div>
  )
}

function DashboardSkeleton() {
  return (
    <div className="flex flex-col gap-6 p-4 md:p-6 lg:p-8">
      <div className="flex flex-col gap-2">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-4 w-72" />
      </div>
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4 lg:gap-4">
        {[...Array(4)].map((_, i) => (
          <Skeleton key={i} className="h-28 rounded-xl" />
        ))}
      </div>
      <div className="grid gap-4 md:grid-cols-2">
        <Skeleton className="h-80 rounded-xl" />
        <Skeleton className="h-80 rounded-xl" />
      </div>
      <div className="grid gap-4 lg:grid-cols-3">
        <Skeleton className="h-96 rounded-xl lg:col-span-2" />
        <Skeleton className="h-96 rounded-xl" />
      </div>
    </div>
  )
}
