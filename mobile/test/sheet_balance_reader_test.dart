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
  });
}
