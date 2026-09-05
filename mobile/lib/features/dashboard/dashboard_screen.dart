import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/split_balance_helper.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _routes = [
    '/',
    '/transactions',
    '/analytics',
    '/sources',
    '/splits',
    '/settings',
  ];

  int _indexForLocation(String location) {
    if (location.startsWith('/transactions')) return 1;
    if (location.startsWith('/analytics')) return 2;
    if (location.startsWith('/sources') ||
        location.startsWith('/apps') ||
        location.startsWith('/methods')) {
      return 3;
    }
    if (location.startsWith('/splits') || location.startsWith('/contacts')) {
      return 4;
    }
    if (location.startsWith('/settings')) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _indexForLocation(location);

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 250) return;
            if (velocity > 0 && index > 0) {
              context.go(_routes[index - 1]);
            } else if (velocity < 0 && index < _routes.length - 1) {
              context.go(_routes[index + 1]);
            }
          },
          child: child,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_routes[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Txns',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Splits',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: index <= 1
          ? FloatingActionButton(
              onPressed: () => context.push('/transactions/new'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final syncStateAsync = ref.watch(syncStateProvider);
    final splitsAsync = ref.watch(billSplitsProvider);
    final settlementsAsync = ref.watch(splitSettlementsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stats) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(transactionsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'SpendWise',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              syncStateAsync.maybeWhen(
                data: (syncState) {
                  if (syncState.googleAccountEmail != null) {
                    return const SizedBox.shrink();
                  }
                  return Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.cloud_upload_outlined),
                      title: const Text('Connect Google (optional)'),
                      subtitle: const Text(
                        'Sign in from Settings to back up data and update your Google Sheet. '
                        'The app works fully offline without Google.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/settings'),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'This month income',
                      value: Formatters.currency.format(stats.monthIncome),
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'This month expense',
                      value: Formatters.currency.format(stats.monthExpense),
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StatCard(
                title: 'Net balance',
                value: Formatters.currency.format(stats.totalBalance),
                color: Theme.of(context).colorScheme.primary,
                subtitle: 'Bank + wallet + cash − credit card bills',
              ),
              const SizedBox(height: 24),
              Text(
                'Recent transactions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (stats.recentTransactions.isEmpty)
                const Text('No transactions yet. Tap + to add one.')
              else
                ...stats.recentTransactions.map(
                  (t) {
                    final split = (splitsAsync.valueOrNull ?? [])
                        .where((s) => s.transactionId == t.id)
                        .firstOrNull;
                    var outstanding = 0.0;
                    if (split != null) {
                      final settlements = (settlementsAsync.valueOrNull ?? [])
                          .where((s) => s.billSplitId == split.id)
                          .toList();
                      outstanding = SplitBalanceHelper.totalOutstanding(
                        split: split,
                        settlements: settlements,
                      );
                    }

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          t.type == TransactionType.income
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: t.type == TransactionType.income
                              ? Colors.green
                              : Colors.red,
                        ),
                        title: Text(t.description),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${Formatters.categoryLabel(t.category)} · ${Formatters.date.format(t.timestamp)}',
                            ),
                            if (split != null && outstanding > 0.009)
                              Text(
                                'To collect ${Formatters.currency.format(outstanding)}',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: split != null && outstanding > 0.009,
                        trailing: Text(
                          Formatters.currency.format(
                            t.type == TransactionType.income
                                ? t.amount
                                : t.netExpenseAmount,
                          ),
                        ),
                        onTap: () => context.push('/transactions/${t.id}'),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
