import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/sheet_sync_registry.dart';

void main() {
  test('plan skips unchanged synced transaction', () {
    final registry = SheetSyncRegistry(':memory:sheet_sync.json');
    final txn = TransactionModel(
      id: 't1',
      type: TransactionType.expense,
      amount: 100,
      category: 'food',
      description: 'Lunch',
      timestamp: DateTime(2026, 1, 1),
      paymentSourceId: 's1',
      updatedAt: DateTime(2026, 1, 2),
    );
    registry.markSynced(
      transactionId: 't1',
      sheetRowNumber: 10,
      syncedUpdatedAt: DateTime(2026, 1, 2),
      paymentSourceId: 's1',
      type: TransactionType.expense,
      amountColumn: 'E',
    );

    expect(registry.plan(txn).action, SheetSyncAction.skip);
  });

  test('plan updates when transaction changed after sync', () {
    final registry = SheetSyncRegistry(':memory:sheet_sync.json');
    registry.markSynced(
      transactionId: 't1',
      sheetRowNumber: 10,
      syncedUpdatedAt: DateTime(2026, 1, 1),
      paymentSourceId: 's1',
      type: TransactionType.expense,
      amountColumn: 'E',
    );
    final txn = TransactionModel(
      id: 't1',
      type: TransactionType.expense,
      amount: 120,
      category: 'food',
      description: 'Lunch',
      timestamp: DateTime(2026, 1, 1),
      paymentSourceId: 's1',
      updatedAt: DateTime(2026, 1, 5),
    );

    final plan = registry.plan(txn);
    expect(plan.action, SheetSyncAction.update);
    expect(plan.sheetRowNumber, 10);
  });

  test('plan appends new transaction', () {
    final registry = SheetSyncRegistry(':memory:sheet_sync.json');
    final txn = TransactionModel(
      id: 'new',
      type: TransactionType.income,
      amount: 50,
      category: 'other',
      description: 'Refund',
      timestamp: DateTime(2026, 1, 1),
      paymentSourceId: 's1',
    );

    expect(registry.plan(txn).action, SheetSyncAction.append);
  });
}
