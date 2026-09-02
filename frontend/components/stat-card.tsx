"use client";

import type { LucideIcon } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";
import { TrendingUp, TrendingDown } from "lucide-react";

interface StatCardProps {
  title: string;
  value: string;
  icon: LucideIcon;
  trend?: number;
  trendLabel?: string;
  variant?: "default" | "income" | "expense" | "cashback";
}

export function StatCard({ title, value, icon: Icon, trend, trendLabel, variant = "default" }: StatCardProps) {
  const iconBg = {
    default: "bg-primary/10 text-primary",
    income: "bg-income/10 text-income",
    expense: "bg-expense/10 text-expense",
    cashback: "bg-cashback/10 text-cashback",
  }[variant];

  return (
    <Card>
      <CardContent className="flex items-start gap-4 p-4 md:p-6">
        <div className={cn("flex h-10 w-10 shrink-0 items-center justify-center rounded-xl", iconBg)}>
          <Icon className="h-5 w-5" />
        </div>
        <div className="flex flex-col gap-1 min-w-0">
          <span className="text-sm text-muted-foreground">{title}</span>
          <span className="text-xl md:text-2xl font-bold tracking-tight truncate">{value}</span>
          {trend !== undefined && (
            <div className="flex items-center gap-1 text-xs">
              {trend >= 0 ? (
                <TrendingUp className="h-3 w-3 text-income" />
              ) : (
                <TrendingDown className="h-3 w-3 text-expense" />
              )}
              <span className={cn(trend >= 0 ? "text-income" : "text-expense")}>
                {trend >= 0 ? "+" : ""}{trend}%
              </span>
              {trendLabel && <span className="text-muted-foreground">{trendLabel}</span>}
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
