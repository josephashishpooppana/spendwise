import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/transaction_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('credit card payment creates paired transactions and updates balances',
      () async {
    final db = await AppDatabase.openMemory();
    final sources = await db.getPaymentSources();
    final bank = sources.firstWhere((s) => s.name == 'ICICI Bank');
    final cc = sources.firstWhere((s) => s.sourceTypeKey == 'CREDIT_CARD');

    await db.updateSourceBalance(bank.id, 10000);
    await db.updateSourceBalance(cc.id, 5000);

    final service = TransactionService(db);
    await service.create(
      CreateTransactionInput(
        type: TransactionType.expense,
        amount: 2000,
        category: 'credit_card_payment',
        description: 'Federal bill',
        timestamp: DateTime.now(),
        paymentSourceId: bank.id,
        creditCardPaymentTargetId: cc.id,
      ),
    );

    final updatedBank = await db.getPaymentSource(bank.id);
    final updatedCc = await db.getPaymentSource(cc.id);
    expect(updatedBank!.balance, 8000);
    expect(updatedCc!.balance, 3000);

    final txns = await db.getTransactions();
    expect(txns.length, 2);
    final expense = txns.firstWhere((t) => t.type == TransactionType.expense);
    final income = txns.firstWhere((t) => t.type == TransactionType.income);
    expect(income.notes, 'paired:${expense.id}');
    expect(income.description, 'Bill payment: Federal bill');
  });
}
