"use client"

import { Pie, PieChart, Cell, ResponsiveContainer } from "recharts"
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
import type { CategoryBreakdown } from "@/lib/types"

interface ExpensePieChartProps {
  data: CategoryBreakdown[]
}

export function ExpensePieChart({ data }: ExpensePieChartProps) {
  const chartData = data.map((d) => ({
    name: d.label,
    value: d.totalAmount,
    color: d.color,
  }))

  const chartConfig = data.reduce<Record<string, { label: string; color: string }>>(
    (acc, d) => {
      acc[d.label] = { label: d.label, color: d.color }
      return acc
    },
    {}
  )

  if (chartData.length === 0) {
    return (
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-base font-semibold">Expenses by Category</CardTitle>
          <CardDescription className="text-xs">Spending breakdown</CardDescription>
        </CardHeader>
        <CardContent className="flex h-[280px] items-center justify-center px-2 pb-4 md:px-6">
          <p className="text-sm text-muted-foreground">No expense data yet</p>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="text-base font-semibold">Expenses by Category</CardTitle>
        <CardDescription className="text-xs">Spending breakdown</CardDescription>
      </CardHeader>
      <CardContent className="px-2 pb-4 md:px-6">
        <ChartContainer config={chartConfig} className="h-[280px] w-full">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
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
              <Pie
                data={chartData}
                dataKey="value"
                nameKey="name"
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={90}
                paddingAngle={2}
              >
                {chartData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
            </PieChart>
          </ResponsiveContainer>
        </ChartContainer>
      </CardContent>
    </Card>
  )
}
