import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/split_balance_helper.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionType? _filterType;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(transactionsProvider);
    final splitsAsync = ref.watch(billSplitsProvider);
    final settlementsAsync = ref.watch(splitSettlementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search description, category, notes…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<TransactionType?>(
                  value: _filterType,
                  hint: const Text('All'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(
                      value: TransactionType.income,
                      child: Text('Income'),
                    ),
                    DropdownMenuItem(
                      value: TransactionType.expense,
                      child: Text('Expense'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _filterType = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: txnsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (txns) {
                final splitsByTxn = {
                  for (final s in splitsAsync.valueOrNull ?? []) s.transactionId: s,
                };
                final settlementsBySplit = <String, List<SplitSettlementModel>>{};
                for (final s in settlementsAsync.valueOrNull ?? []) {
                  settlementsBySplit
                      .putIfAbsent(s.billSplitId, () => [])
                      .add(s);
                }

                final filtered = txns.where((t) {
                  if (_filterType != null && t.type != _filterType) {
                    return false;
                  }
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    return t.description.toLowerCase().contains(q) ||
                        t.category.toLowerCase().contains(q) ||
                        (t.notes?.toLowerCase().contains(q) ?? false);
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      _search.isNotEmpty
                          ? 'No transactions match "$_search"'
                          : 'No transactions found',
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        _search.isNotEmpty
                            ? '${filtered.length} of ${txns.length} transactions'
                            : '${txns.length} transactions',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final t = filtered[index];
                    final split = splitsByTxn[t.id];
                    var outstanding = 0.0;
                    if (split != null) {
                      outstanding = SplitBalanceHelper.totalOutstanding(
                        split: split,
                        settlements:
                            settlementsBySplit[split.id] ?? const [],
                      );
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: t.type == TransactionType.income
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        child: Icon(
                          t.type == TransactionType.income
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: t.type == TransactionType.income
                              ? Colors.green
                              : Colors.red,
                          size: 18,
                        ),
                      ),
                      title: Text(t.description),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${Formatters.txnType(t.type)} · ${Formatters.categoryLabel(t.category)}',
                          ),
                          if (split != null && outstanding > 0.009)
                            Text(
                              'To collect ${Formatters.currency.format(outstanding)}',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else if (split != null && split.isSettled)
                            const Text(
                              'Split settled',
                              style: TextStyle(color: Colors.green),
                            ),
                        ],
                      ),
                      isThreeLine: split != null,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.currency.format(
                              t.type == TransactionType.income
                                  ? t.amount
                                  : t.netExpenseAmount,
                            ),
                          ),
                          if (split != null)
                            Icon(
                              outstanding < 0.01
                                  ? Icons.check_circle
                                  : Icons.pending_actions,
                              size: 16,
                              color: outstanding < 0.01
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                        ],
                      ),
                      onTap: () => context.push('/transactions/${t.id}'),
                    );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
