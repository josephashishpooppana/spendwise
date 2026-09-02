import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/sheet_parser.dart';

void main() {
  group('SheetParser', () {
    test('parseRow reads ICICI debit expense', () {
      final row = List<Object?>.filled(45, '');
      row[1] = 45293.0; // date
      row[2] = 'Tea';
      row[4] = 30.0; // E = ICICI debit

      final parsed = SheetParser.parseRow(row, sheetRowNumber: 5);
      expect(parsed.length, 1);
      expect(parsed.first.type, TransactionType.expense);
      expect(parsed.first.amount, 30);
      expect(parsed.first.sourceNamePattern, 'ICICI Bank');
      expect(parsed.first.description, 'Tea');
    });

    test('parseRow reads BOB credit income', () {
      final row = List<Object?>.filled(45, '');
      row[1] = 45294.0;
      row[2] = 'Salary';
      row[6] = 23000.0; // G = BOB credit

      final parsed = SheetParser.parseRow(row, sheetRowNumber: 8);
      expect(parsed.length, 1);
      expect(parsed.first.type, TransactionType.income);
      expect(parsed.first.amount, 23000);
      expect(parsed.first.sourceNamePattern, 'BOB');
    });

    test('parseRow skips empty rows', () {
      final row = List<Object?>.filled(45, '');
      expect(SheetParser.parseRow(row, sheetRowNumber: 3), isEmpty);
    });

    test('importId is stable for deduplication', () {
      final row = List<Object?>.filled(45, '');
      row[1] = 45293.0;
      row[2] = 'Bus';
      row[4] = 40.0;

      final parsed = SheetParser.parseRow(row, sheetRowNumber: 6);
      expect(parsed.first.importId, 'sheet-6-E-40.00');
    });

    test('excel serial date converts correctly', () {
      final date = SheetParser.parseDate(null, 45291.0);
      expect(date, isNotNull);
      expect(date!.month, greaterThan(0));
    });
  });
}
