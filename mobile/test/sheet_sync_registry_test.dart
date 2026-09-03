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

  test('shiftRowNumbers adjusts entries and pending deletes', () {
    final registry = SheetSyncRegistry(':memory:sheet_sync.json');
    registry.markSynced(
      transactionId: 't1',
      sheetRowNumber: 10,
      syncedUpdatedAt: DateTime(2026, 1, 1),
      paymentSourceId: 's1',
      type: TransactionType.expense,
      amountColumn: 'E',
    );
    registry.markSynced(
      transactionId: 't2',
      sheetRowNumber: 12,
      syncedUpdatedAt: DateTime(2026, 1, 1),
      paymentSourceId: 's1',
      type: TransactionType.expense,
      amountColumn: 'E',
    );
    registry.queueSheetDelete(transactionId: 'gone', sheetRowNumber: 11);

    registry.shiftRowNumbers(11, -1);

    expect(registry.entryFor('t1')!.sheetRowNumber, 10);
    expect(registry.entryFor('t2')!.sheetRowNumber, 11);
    expect(registry.pendingDeletes.single.sheetRowNumber, 10);
  });

  test('queueSheetDelete dedupes by transaction id', () {
    final registry = SheetSyncRegistry(':memory:sheet_sync.json');
    registry.queueSheetDelete(transactionId: 't1', sheetRowNumber: 5);
    registry.queueSheetDelete(transactionId: 't1', sheetRowNumber: 8);

    expect(registry.pendingDeletes.length, 1);
    expect(registry.pendingDeletes.single.sheetRowNumber, 8);
  });

  test('toExportJson includes pending deletes', () {
    final registry = SheetSyncRegistry(':memory:sheet_sync.json');
    registry.queueSheetDelete(transactionId: 't1', sheetRowNumber: 42);

    final json = registry.toExportJson();
    final deletes = json['pendingDeletes'] as List<dynamic>;
    expect(deletes.single['sheetRowNumber'], 42);
  });
}
