import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/integrations/sheet_row_inserter.dart';

void main() {
  group('SheetRowInserter', () {
    test('inserts before first later-dated row', () {
      final rows = <List<Object?>>[
        ['Monday', DateTime(2026, 1, 1), 'Tea'],
        ['Wednesday', DateTime(2026, 1, 3), 'Lunch'],
      ];

      final target = SheetRowInserter.targetInsertRow(
        txnDate: DateTime(2026, 1, 2),
        sheetRows: rows,
      );

      expect(target, 4);
    });

    test('inserts after last row when date is newest', () {
      final rows = <List<Object?>>[
        ['Monday', DateTime(2026, 1, 1), 'Tea'],
        ['Tuesday', DateTime(2026, 1, 2), 'Lunch'],
      ];

      final target = SheetRowInserter.targetInsertRow(
        txnDate: DateTime(2026, 1, 5),
        sheetRows: rows,
      );

      expect(target, 5);
    });

    test('inserts at row 3 when sheet is empty', () {
      expect(
        SheetRowInserter.targetInsertRow(
          txnDate: DateTime(2026, 1, 1),
          sheetRows: const [],
        ),
        3,
      );
    });

    test('placeholder insert shifts later targets', () {
      final rows = <List<Object?>>[
        ['Monday', DateTime(2026, 1, 1), 'Tea'],
        ['Wednesday', DateTime(2026, 1, 3), 'Lunch'],
      ];
      final snapshot = rows.map((r) => List<Object?>.from(r)).toList();

      final first = SheetRowInserter.targetInsertRow(
        txnDate: DateTime(2026, 1, 2),
        sheetRows: snapshot,
      );
      SheetRowInserter.insertPlaceholderRowAt(snapshot, first);

      final second = SheetRowInserter.targetInsertRow(
        txnDate: DateTime(2026, 1, 4),
        sheetRows: snapshot,
      );

      expect(first, 4);
      expect(second, 6);
    });
  });
}
