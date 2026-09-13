import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/sheet_balance_reader.dart';

void main() {
  group('SheetBalanceReader', () {
    test('reads bank balance and card bill total from last dated row', () {
      final last = List<Object?>.filled(16, '');
      last[0] = 'Tuesday';
      last[1] = 45291.0;
      last[2] = 'Salary';
      last[5] = 5000.0; // F = ICICI balance
      last[15] = 12500.0; // P = Federal CC bill total

      final rows = <List<Object?>>[
        ['Monday', 45290.0, 'Tea', '', 30.0, 1000.0],
        last,
      ];

      const sources = [
        PaymentSourceModel(
          id: 'bank',
          name: 'ICICI Bank',
          sourceTypeKey: 'BANK',
          sheetCreditColumn: 'D',
          sheetDebitColumn: 'E',
          sheetBalanceColumn: 'F',
        ),
        PaymentSourceModel(
          id: 'cc',
          name: 'Federal Bank Credit Card',
          sourceTypeKey: 'CREDIT_CARD',
          sheetCreditColumn: 'N',
          sheetDebitColumn: 'O',
          sheetBalanceColumn: 'P',
        ),
      ];

      expect(SheetBalanceReader.findLastDataRowIndex(rows), 1);

      final balances = SheetBalanceReader.fromLastSheetRow(
        rows: rows,
        sources: sources,
      );

      expect(balances['bank'], 5000.0);
      expect(balances['cc'], 12500.0);
    });

    test('findLastDataRowIndex skips trailing empty rows', () {
      final rows = <List<Object?>>[
        ['Monday', 45290.0, 'Tea'],
        ['', '', ''],
      ];
      expect(SheetBalanceReader.findLastDataRowIndex(rows), 0);
    });

    test('per-source uses balance-only row per account', () {
      final rows = <List<Object?>>[
        ['Monday', 45290.0, 'Tea', '', 30.0, 1000.0],
        ['Tuesday', 45291.0, '', '', null, 5000.0, null, null, null, null, null, null, null, null, null, 12500.0],
      ];

      const sources = [
        PaymentSourceModel(
          id: 'bank',
          name: 'ICICI Bank',
          sourceTypeKey: 'BANK',
          sheetCreditColumn: 'D',
          sheetDebitColumn: 'E',
          sheetBalanceColumn: 'F',
        ),
        PaymentSourceModel(
          id: 'cc',
          name: 'Federal Bank Credit Card',
          sourceTypeKey: 'CREDIT_CARD',
          sheetCreditColumn: 'N',
          sheetDebitColumn: 'O',
          sheetBalanceColumn: 'P',
        ),
      ];

      final perSource = SheetBalanceReader.perSourceFromSheet(
        rows: rows,
        sources: sources,
      );

      expect(perSource['bank']!.amount, 5000.0);
      expect(perSource['bank']!.sheetRowNumber, 4);
      expect(perSource['cc']!.amount, 12500.0);
      expect(perSource['cc']!.sheetRowNumber, 4);
    });

    test('cash balance ignores blank rows with inherited credit/debit', () {
      final rows = <List<Object?>>[
        ['Monday', 45290.0, 'Tea', null, null, 1000.0],
        ['Tuesday', 45291.0, '', null, 40.0, 34905.50],
        ['Wednesday', 45292.0, 'Bus', null, 25.0, 34880.50],
      ];

      const cash = PaymentSourceModel(
        id: 'cash',
        name: 'Cash In Hand',
        sourceTypeKey: 'CASH',
        sheetCreditColumn: 'D',
        sheetDebitColumn: 'E',
        sheetBalanceColumn: 'F',
      );

      final reading = SheetBalanceReader.balanceForSource(
        rows: rows,
        source: cash,
        firstDataRowNumber: 3,
      );

      expect(reading!.amount, 34880.50);
      expect(reading.sheetRowNumber, 5);
    });

    test('cash balance uses W/X/Y columns like Daily Expenses sheet', () {
      final row = List<Object?>.filled(30, '');
      row[0] = 'Saturday';
      row[1] = 45295.0;
      row[2] = 'Milk';
      row[23] = 40.0; // X debit
      row[24] = 34905.50; // Y balance

      const cash = PaymentSourceModel(
        id: 'cash',
        name: 'Cash In Hand',
        sourceTypeKey: 'CASH',
        sheetCreditColumn: 'W',
        sheetDebitColumn: 'X',
        sheetBalanceColumn: 'Y',
      );

      final reading = SheetBalanceReader.balanceForSource(
        rows: [row],
        source: cash,
        firstDataRowNumber: 3,
      );

      expect(reading!.amount, 34905.50);
      expect(reading.sheetRowNumber, 3);
    });
  });
}
