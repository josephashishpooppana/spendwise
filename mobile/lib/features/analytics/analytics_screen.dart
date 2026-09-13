import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _monthCategories = true;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(analyticsStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) {
          final categories = _monthCategories
              ? stats.monthCategoryTotals
              : stats.categoryTotals;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(analyticsStatsProvider);
              ref.invalidate(transactionsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Month income',
                        value: Formatters.currency.format(stats.monthIncome),
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        title: 'Month expense',
                        value: Formatters.currency.format(stats.monthExpense),
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Net saved',
                        value: Formatters.currency.format(stats.netSaved),
                        color: stats.netSaved >= 0
                            ? Colors.teal.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        title: 'Net balance',
                        value: Formatters.currency.format(stats.netBalance),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('6-month trend', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: _TrendChart(points: stats.monthlyTrend),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text('By category', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Month')),
                        ButtonSegment(value: false, label: Text('All time')),
                      ],
                      selected: {_monthCategories},
                      onSelectionChanged: (s) =>
                          setState(() => _monthCategories = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (categories.isEmpty)
                  const Text('No expense data yet.')
                else ...[
                  SizedBox(
                    height: 200,
                    child: _CategoryPieChart(categories: categories),
                  ),
                  const SizedBox(height: 8),
                  ...(() {
                    final sorted = categories.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    return sorted.take(8).map(
                          (e) => ListTile(
                            dense: true,
                            title: Text(Formatters.categoryLabel(e.key)),
                            trailing:
                                Text(Formatters.currency.format(e.value)),
                          ),
                        );
                  })(),
                ],
                const SizedBox(height: 24),
                Text('Top spending', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (stats.topDescriptions.isEmpty)
                  const Text('No expenses recorded.')
                else
                  ...stats.topDescriptions.map(
                    (e) => ListTile(
                      dense: true,
                      title: Text(e.key),
                      trailing: Text(Formatters.currency.format(e.value)),
                    ),
                  ),
                const SizedBox(height: 24),
                Text('By account', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...stats.spendingBySource.take(8).map(
                      (e) => ListTile(
                        dense: true,
                        title: Text(e.sourceName),
                        trailing: Text(Formatters.currency.format(e.amount)),
                      ),
                    ),
                const SizedBox(height: 24),
                Text('Cashback', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('This month'),
                  trailing: Text(Formatters.currency.format(stats.monthCashback)),
                ),
                ListTile(
                  title: const Text('All time'),
                  trailing: Text(Formatters.currency.format(stats.allTimeCashback)),
                ),
                if (stats.creditCardStats.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Credit cards', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...stats.creditCardStats.map(
                    (c) => Card(
                      child: ListTile(
                        title: Text(c.name),
                        subtitle: Text(
                          [
                            'Bill ${Formatters.currency.format(c.billTotal)}',
                            if (c.utilizationPercent != null)
                              '${c.utilizationPercent!.toStringAsFixed(0)}% used',
                            if (c.daysToStatement != null)
                              'Statement in ${c.daysToStatement} days',
                          ].join(' · '),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text('Highlights', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Avg daily spend (30 days)'),
                  trailing:
                      Text(Formatters.currency.format(stats.avgDailySpend30Days)),
                ),
                if (stats.largestExpense != null)
                  ListTile(
                    title: const Text('Largest expense'),
                    subtitle: Text(stats.largestExpense!.description),
                    trailing: Text(
                      Formatters.currency.format(
                        stats.largestExpense!.netExpenseAmount,
                      ),
                    ),
                  ),
                if (stats.splitOutstanding > 0)
                  ListTile(
                    title: const Text('Split outstanding'),
                    trailing:
                        Text(Formatters.currency.format(stats.splitOutstanding)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<MonthlyTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const Center(child: Text('No data'));

    final maxY = points
        .map((p) => p.income > p.expense ? p.income : p.expense)
        .fold(0.0, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 100 : maxY * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[i].label,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].income,
                  color: Colors.green.shade400,
                  width: 8,
                ),
                BarChartRodData(
                  toY: points[i].expense,
                  color: Colors.red.shade400,
                  width: 8,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  const _CategoryPieChart({required this.categories});

  final Map<String, double> categories;

  static const _colors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFFE91E63),
    Color(0xFF009688),
    Color(0xFF795548),
    Color(0xFF607D8B),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0.0, (sum, e) => sum + e.value);
    if (total <= 0) return const Center(child: Text('No data'));

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 36,
        sections: [
          for (var i = 0; i < entries.length && i < 8; i++)
            PieChartSectionData(
              value: entries[i].value,
              title: '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
              color: _colors[i % _colors.length],
              radius: 52,
              titleStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
