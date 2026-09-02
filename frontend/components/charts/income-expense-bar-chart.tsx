"use client"

import {
  Bar,
  BarChart,
  XAxis,
  YAxis,
  CartesianGrid,
  ResponsiveContainer,
  Legend,
} from "recharts"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
} from "@/components/ui/chart"
import type { TrendDataPoint } from "@/lib/types"

interface IncomeExpenseBarChartProps {
  data: TrendDataPoint[]
}

const chartConfig = {
  income: {
    label: "Income",
    color: "#22c55e",
  },
  expenses: {
    label: "Expenses",
    color: "#ef4444",
  },
}

export function IncomeExpenseBarChart({ data }: IncomeExpenseBarChartProps) {
  const chartData = data.map((d) => ({
    period: d.period.replace(" 20", " '"),
    income: d.income,
    expenses: d.expenses,
  }))

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-base font-semibold">Income vs Expenses</CardTitle>
        <CardDescription className="text-xs">Last 6 months trend</CardDescription>
      </CardHeader>
      <CardContent className="px-2 pb-4 md:px-6">
        <ChartContainer config={chartConfig} className="h-[280px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={chartData} margin={{ top: 5, right: 10, left: -10, bottom: 0 }}>
              <CartesianGrid vertical={false} strokeDasharray="3 3" className="stroke-border" />
              <XAxis
                dataKey="period"
                tickLine={false}
                axisLine={false}
                fontSize={11}
                className="fill-muted-foreground"
              />
              <YAxis
                tickLine={false}
                axisLine={false}
                fontSize={11}
                className="fill-muted-foreground"
                tickFormatter={(v) => `${(v / 1000).toFixed(0)}K`}
              />
              <ChartTooltip
                content={
                  <ChartTooltipContent
                    formatter={(value) =>
                      new Intl.NumberFormat("en-IN", {
                        style: "currency",
                        currency: "INR",
                        minimumFractionDigits: 0,
                      }).format(value as number)
                    }
                  />
                }
              />
              <Legend
                verticalAlign="top"
                align="right"
                iconType="circle"
                iconSize={8}
                wrapperStyle={{ fontSize: 12, paddingBottom: 8 }}
              />
              <Bar dataKey="income" fill="#22c55e" radius={[4, 4, 0, 0]} barSize={20} />
              <Bar dataKey="expenses" fill="#ef4444" radius={[4, 4, 0, 0]} barSize={20} />
            </BarChart>
          </ResponsiveContainer>
        </ChartContainer>
      </CardContent>
    </Card>
  )
}
