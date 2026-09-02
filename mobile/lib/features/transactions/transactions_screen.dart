import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/data/models/models.dart';

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
                      hintText: 'Search...',
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
                final filtered = txns.where((t) {
                  if (_filterType != null && t.type != _filterType) {
                    return false;
                  }
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    return t.description.toLowerCase().contains(q) ||
                        t.category.toLowerCase().contains(q);
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No transactions found'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final t = filtered[index];
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
                      subtitle: Text(
                        '${Formatters.txnType(t.type)} · ${Formatters.categoryLabel(t.category)}',
                      ),
                      trailing: Text(
                        Formatters.currency.format(
                          t.type == TransactionType.income
                              ? t.amount
                              : t.netExpenseAmount,
                        ),
                      ),
                      onTap: () => context.push('/transactions/${t.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
