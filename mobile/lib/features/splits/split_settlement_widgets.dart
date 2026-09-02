import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/split_balance_helper.dart';
import 'package:spendwise_mobile/domain/services/split_service.dart';

class SplitMembersSection extends ConsumerWidget {
  const SplitMembersSection({
    super.key,
    required this.split,
    required this.expense,
    required this.contactsById,
    required this.settlements,
    this.onChanged,
  });

  final BillSplitModel split;
  final TransactionModel expense;
  final Map<String, ContactModel> contactsById;
  final List<SplitSettlementModel> settlements;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outstanding = SplitBalanceHelper.totalOutstanding(
      split: split,
      settlements: settlements,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (outstanding > 0.009)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'To collect: ${Formatters.currency.format(outstanding)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        Card(
          child: Column(
            children: [
              ListTile(
                dense: true,
                leading: Icon(
                  split.isSettled ? Icons.check_circle : Icons.hourglass_top,
                  color: split.isSettled ? Colors.green : Colors.orange,
                ),
                title: Text(
                  split.splitType == SplitType.equal
                      ? 'Equal split'
                      : 'Custom split',
                ),
                subtitle: Text(
                  split.isSettled ? 'All members paid' : 'Pending collections',
                ),
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.person, color: Colors.blue),
                title: const Text('Me (paid)'),
                trailing: Text(
                  Formatters.currency.format(
                    split.splitType == SplitType.equal
                        ? SplitService.myEqualShare(
                            totalAmount: expense.amount,
                            contactIds: split.splitDetails.keys.toList(),
                          )
                        : (split.myShare ??
                            expense.amount -
                                split.splitDetails.values
                                    .fold(0.0, (a, b) => a + b)),
                  ),
                ),
              ),
              ...split.splitDetails.entries.map((entry) {
                final contactId = entry.key;
                final owed = entry.value;
                final paid = SplitBalanceHelper.paidAmount(
                  settlements,
                  contactId,
                );
                final remaining = SplitBalanceHelper.remainingForContact(
                  split: split,
                  settlements: settlements,
                  contactId: contactId,
                );
                final fullyPaid = remaining < 0.01;
                final name = contactsById[contactId]?.name ?? contactId;

                return ListTile(
                  dense: true,
                  leading: Icon(
                    fullyPaid
                        ? Icons.check_circle
                        : paid > 0
                            ? Icons.pie_chart_outline
                            : Icons.radio_button_unchecked,
                    color: fullyPaid
                        ? Colors.green
                        : paid > 0
                            ? Colors.amber.shade800
                            : Colors.grey,
                  ),
                  title: Text(name),
                  subtitle: fullyPaid
                      ? Text('Paid ${Formatters.currency.format(paid)}')
                      : paid > 0
                          ? Text(
                              'Paid ${Formatters.currency.format(paid)} · '
                              'Due ${Formatters.currency.format(remaining)}',
                            )
                          : Text('Owes ${Formatters.currency.format(owed)}'),
                  trailing: fullyPaid
                      ? null
                      : TextButton(
                          onPressed: () => _showMarkPaidDialog(
                            context,
                            ref,
                            contactId: contactId,
                            contactName: name,
                            defaultAmount: remaining,
                          ),
                          child: const Text('Mark paid'),
                        ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showMarkPaidDialog(
    BuildContext context,
    WidgetRef ref, {
    required String contactId,
    required String contactName,
    required double defaultAmount,
  }) async {
    final amountCtrl = TextEditingController(
      text: defaultAmount.toStringAsFixed(defaultAmount.truncateToDouble() == defaultAmount ? 0 : 2),
    );
    String? sourceId;
    final sources = await ref.read(paymentSourcesProvider.future);
    final incomeSources = sources
        .where((s) => s.isActive && s.sourceTypeKey != 'DEBIT_CARD')
        .toList();
    if (incomeSources.isNotEmpty) {
      sourceId = incomeSources.first.id;
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Mark paid · $contactName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount received',
                  helperText:
                      'Default: ${Formatters.currency.format(defaultAmount)}',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: sourceId,
                decoration: const InputDecoration(labelText: 'Credited to'),
                items: incomeSources
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => sourceId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: sourceId == null
                  ? null
                  : () async {
                      final amount =
                          double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amount <= 0) return;
                      try {
                        final service =
                            await ref.read(splitSettlementServiceProvider.future);
                        await service.markMemberPaid(
                          split: split,
                          expense: expense,
                          contactId: contactId,
                          contactName: contactName,
                          amount: amount,
                          paymentSourceId: sourceId!,
                        );
                        ref.invalidate(splitSettlementsProvider);
                        ref.invalidate(billSplitsProvider);
                        ref.invalidate(transactionsProvider);
                        ref.invalidate(paymentSourcesProvider);
                        ref.invalidate(dashboardStatsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        onChanged?.call();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
              child: const Text('Save income'),
            ),
          ],
        ),
      ),
    );
  }
}
