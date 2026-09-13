import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('getFrequentDescriptions returns top descriptions by usage', () async {
    final db = await AppDatabase.openMemory();
    final sources = await db.getPaymentSources();
    final source = sources.first;

    await db.insertTransaction(
      TransactionModel(
        id: 't1',
        type: TransactionType.expense,
        amount: 100,
        category: 'groceries',
        description: 'BigBasket',
        timestamp: DateTime(2025, 1, 1),
        paymentSourceId: source.id,
        paymentMethodId: 'pm-upi',
      ),
    );
    await db.insertTransaction(
      TransactionModel(
        id: 't2',
        type: TransactionType.expense,
        amount: 50,
        category: 'food_dining',
        description: 'BigBasket',
        timestamp: DateTime(2025, 1, 2),
        paymentSourceId: source.id,
        paymentMethodId: 'pm-upi',
      ),
    );
    await db.insertTransaction(
      TransactionModel(
        id: 't3',
        type: TransactionType.expense,
        amount: 30,
        category: 'transport',
        description: 'Uber',
        timestamp: DateTime(2025, 1, 3),
        paymentSourceId: source.id,
        paymentMethodId: 'pm-upi',
      ),
    );

    final frequent = await db.getFrequentDescriptions(limit: 8);
    expect(frequent.first, 'BigBasket');
    expect(frequent.length, lessThanOrEqualTo(8));
  });
}
