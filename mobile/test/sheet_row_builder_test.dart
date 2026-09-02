import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/sheet_row_builder.dart';

void main() {
  test('buildRow places expense debit in ICICI column', () {
    final txn = TransactionModel(
      id: '1',
      type: TransactionType.expense,
      amount: 100,
      category: 'groceries',
      description: 'Tea',
      timestamp: DateTime(2024, 1, 15),
      paymentSourceId: 's1',
      cashbackReceived: 10,
    );
    const source = PaymentSourceModel(
      id: 's1',
      name: 'ICICI Bank',
      sourceTypeKey: 'BANK',
      sheetCreditColumn: 'D',
      sheetDebitColumn: 'E',
    );

    final row = SheetRowBuilder.buildRow(
      transaction: txn,
      source: source,
      metadataStartColumnIndex: 26,
    );

    expect(row.length, 53);
    expect(row[0], 'Monday');
    expect(row[2], 'Tea');
    expect(row[4], 90.0); // column E = debit for ICICI
    expect(row[26], '1'); // AA = transaction id
  });

  test('buildRow places income credit in cash column', () {
    final txn = TransactionModel(
      id: '2',
      type: TransactionType.income,
      amount: 500,
      category: 'salary',
      description: 'Salary',
      timestamp: DateTime(2024, 1, 15),
      paymentSourceId: 's1',
    );
    const source = PaymentSourceModel(
      id: 's1',
      name: 'Cash In Hand',
      sourceTypeKey: 'CASH',
      sheetCreditColumn: 'W',
      sheetDebitColumn: 'X',
    );

    final row = SheetRowBuilder.buildRow(
      transaction: txn,
      source: source,
      metadataStartColumnIndex: 26,
    );

    expect(row[22], 500.0); // column W = credit for cash
  });
}
