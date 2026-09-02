import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/sheet_parser.dart';

void main() {
  group('SheetParser', () {
    const mappings = [
      SheetColumnMapping(
        sourceNamePattern: 'ICICI Bank',
        creditColumn: 'D',
        debitColumn: 'E',
      ),
      SheetColumnMapping(
        sourceNamePattern: 'BOB',
        creditColumn: 'G',
        debitColumn: 'H',
      ),
    ];
    const metadataStart = 26;

    test('parseRow reads ICICI debit expense', () {
      final row = List<Object?>.filled(45, '');
      row[1] = 45293.0; // date
      row[2] = 'Tea';
      row[4] = 30.0; // E = ICICI debit

      final parsed = SheetParser.parseRow(
        row,
        sheetRowNumber: 5,
        mappings: mappings,
        metadataStartColumnIndex: metadataStart,
      );
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

      final parsed = SheetParser.parseRow(
        row,
        sheetRowNumber: 8,
        mappings: mappings,
        metadataStartColumnIndex: metadataStart,
      );
      expect(parsed.length, 1);
      expect(parsed.first.type, TransactionType.income);
      expect(parsed.first.amount, 23000);
      expect(parsed.first.sourceNamePattern, 'BOB');
    });

    test('parseRow skips empty rows', () {
      final row = List<Object?>.filled(45, '');
      expect(
        SheetParser.parseRow(
          row,
          sheetRowNumber: 3,
          mappings: mappings,
          metadataStartColumnIndex: metadataStart,
        ),
        isEmpty,
      );
    });

    test('parseRow skips rows with empty description', () {
      final row = List<Object?>.filled(45, '');
      row[1] = 45293.0;
      row[4] = 30.0;

      expect(
        SheetParser.parseRow(
          row,
          sheetRowNumber: 4,
          mappings: mappings,
          metadataStartColumnIndex: metadataStart,
        ),
        isEmpty,
      );
    });

    test('importId is stable for deduplication', () {
      final row = List<Object?>.filled(45, '');
      row[1] = 45293.0;
      row[2] = 'Bus';
      row[4] = 40.0;

      final parsed = SheetParser.parseRow(
        row,
        sheetRowNumber: 6,
        mappings: mappings,
        metadataStartColumnIndex: metadataStart,
      );
      expect(parsed.first.importId, 'sheet-6-E-40.00');
    });

    test('excel serial date converts correctly', () {
      final date = SheetParser.parseDate(null, 45291.0);
      expect(date, isNotNull);
      expect(date!.month, greaterThan(0));
    });

    test('parseDate reads DD/MM/YYYY strings', () {
      final date = SheetParser.parseDate(null, '02/09/2025');
      expect(date, DateTime(2025, 9, 2));
    });

    test('skips zero or negative credit and debit for all accounts', () {
      const bankMapping = SheetColumnMapping(
        sourceNamePattern: 'ICICI Bank',
        creditColumn: 'D',
        debitColumn: 'E',
      );
      const ccMapping = SheetColumnMapping(
        sourceNamePattern: 'Federal Bank Credit Card',
        creditColumn: 'N',
        debitColumn: 'O',
        sourceTypeKey: 'CREDIT_CARD',
      );

      final zeroDebitRow = List<Object?>.filled(45, '');
      zeroDebitRow[1] = 45293.0;
      zeroDebitRow[2] = 'Placeholder';
      zeroDebitRow[4] = 0.0;

      expect(
        SheetParser.parseRow(
          zeroDebitRow,
          sheetRowNumber: 10,
          mappings: const [bankMapping],
          metadataStartColumnIndex: metadataStart,
        ),
        isEmpty,
      );

      final negativeDebitRow = List<Object?>.filled(45, '');
      negativeDebitRow[1] = 45293.0;
      negativeDebitRow[2] = 'Refund to bank';
      negativeDebitRow[4] = -120.0;

      expect(
        SheetParser.parseRow(
          negativeDebitRow,
          sheetRowNumber: 11,
          mappings: const [bankMapping],
          metadataStartColumnIndex: metadataStart,
        ),
        isEmpty,
      );

      final negativeCreditRow = List<Object?>.filled(45, '');
      negativeCreditRow[1] = 45293.0;
      negativeCreditRow[2] = 'Reversal';
      negativeCreditRow[3] = -80.0;

      expect(
        SheetParser.parseRow(
          negativeCreditRow,
          sheetRowNumber: 12,
          mappings: const [bankMapping],
          metadataStartColumnIndex: metadataStart,
        ),
        isEmpty,
      );

      final ccRow = List<Object?>.filled(45, '');
      ccRow[1] = 45293.0;
      ccRow[2] = 'Card refund';
      ccRow[14] = -100.0;

      expect(
        SheetParser.parseRow(
          ccRow,
          sheetRowNumber: 13,
          mappings: const [ccMapping],
          metadataStartColumnIndex: metadataStart,
        ),
        isEmpty,
      );

      final validRow = List<Object?>.filled(45, '');
      validRow[1] = 45293.0;
      validRow[2] = 'Amazon';
      validRow[14] = 500.0;

      final charge = SheetParser.parseRow(
        validRow,
        sheetRowNumber: 14,
        mappings: const [ccMapping],
        metadataStartColumnIndex: metadataStart,
      );
      expect(charge.length, 1);
      expect(charge.first.type, TransactionType.expense);
      expect(charge.first.amount, 500);
    });

    test('importId ignores non-uuid metadata transaction ids', () {
      final row = List<Object?>.filled(45, '');
      row[1] = 45293.0;
      row[2] = 'Bus';
      row[4] = 40.0;
      row[26] = 'Saturday';

      final parsed = SheetParser.parseRow(
        row,
        sheetRowNumber: 6,
        mappings: mappings,
        metadataStartColumnIndex: metadataStart,
      );
      expect(parsed.first.importId, 'sheet-6-E-40.00');
    });

    test('mappingsFromSheetHeaders finds bank and credit card columns', () {
      final header = List<Object?>.filled(30, '');
      header[3] = 'Kotak Bank';
      header[13] = 'Federal Bank Credit Card';
      final sub = List<Object?>.filled(30, '');
      sub[3] = 'Credit';
      sub[4] = 'Debit';
      sub[5] = 'Balance';
      sub[13] = 'Credit';
      sub[14] = 'Debit';
      sub[15] = 'Bill Total';

      final mappings = SheetParser.mappingsFromSheetHeaders(
        header,
        sub,
        metadataStartColumnIndex: 26,
      );

      expect(mappings.length, 2);
      expect(
        mappings.any(
          (m) =>
              m.sourceNamePattern == 'Kotak Bank' &&
              m.sourceTypeKey == 'BANK' &&
              m.debitColumn == 'E',
        ),
        isTrue,
      );
      expect(
        mappings.any(
          (m) =>
              m.sourceNamePattern == 'Federal Bank Credit Card' &&
              m.sourceTypeKey == 'CREDIT_CARD' &&
              m.debitColumn == 'O',
        ),
        isTrue,
      );
    });

    test('buildImportMappings prefers app sources over headers on same column', () {
      const existing = PaymentSourceModel(
        id: 'icici',
        name: 'ICICI Bank',
        sourceTypeKey: 'BANK',
        sheetCreditColumn: 'D',
        sheetDebitColumn: 'E',
        sheetBalanceColumn: 'F',
      );
      final header = List<Object?>.filled(10, '');
      header[3] = 'ICICI Bank';
      final sub = List<Object?>.filled(10, '');
      sub[3] = 'Credit';
      sub[4] = 'Debit';
      sub[5] = 'Balance';

      final mappings = SheetParser.buildImportMappings(
        sources: const [existing],
        headerRow: header,
        subHeaderRow: sub,
        metadataStartColumnIndex: 26,
      );

      expect(mappings.length, 1);
      expect(mappings.first.sourceId, 'icici');
    });
  });
}
