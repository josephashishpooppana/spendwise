import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/cashback_service.dart';
import 'package:spendwise_mobile/domain/services/transaction_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('create expense with cashback updates net balance', () async {
    final db = await AppDatabase.openMemory();
    final sources = await db.getPaymentSources();
    final icici = sources.firstWhere((s) => s.name == 'ICICI Bank');

    await db.updateSourceBalance(icici.id, 1000);

    final service = TransactionService(db);
    await service.create(
      CreateTransactionInput(
        type: TransactionType.expense,
        amount: 100,
        category: 'groceries',
        description: 'Test grocery',
        timestamp: DateTime.now(),
        paymentSourceId: icici.id,
        paymentMethodId: 'pm-upi',
        cashbackEntries: const [
          CashbackEntryInput(kind: CashbackKind.fixed, amount: 10),
        ],
      ),
    );

    final updated = await db.getPaymentSource(icici.id);
    // Net debit = 100 - 10 cashback; cashback credited back as income to same source
    expect(updated!.balance, closeTo(1000 - 90 + 10, 0.01));
  });
}
