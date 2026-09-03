import 'package:spendwise_mobile/integrations/sheet_parser.dart';

/// Computes 1-based sheet row numbers for chronological insertion.
class SheetRowInserter {
  static const defaultFirstDataRowNumber = 3;

  /// Returns the 1-based row where a new transaction row should be inserted.
  static int targetInsertRow({
    required DateTime txnDate,
    required List<List<Object?>> sheetRows,
    int firstDataRowNumber = defaultFirstDataRowNumber,
  }) {
    final txnDay = DateTime(txnDate.year, txnDate.month, txnDate.day);
    var insertAfter = firstDataRowNumber - 1;

    for (var i = 0; i < sheetRows.length; i++) {
      final sheetRowNumber = firstDataRowNumber + i;
      final row = sheetRows[i];
      final date = SheetParser.parseDate(
        row.isNotEmpty ? row[0] : null,
        row.length > 1 ? row[1] : null,
      );
      if (date == null) continue;

      final rowDay = DateTime(date.year, date.month, date.day);
      if (rowDay.isAfter(txnDay)) {
        return sheetRowNumber;
      }
      insertAfter = sheetRowNumber;
    }

    return insertAfter + 1;
  }

  /// Inserts a placeholder row into a local snapshot (for batch insert planning).
  static void insertPlaceholderRowAt(
    List<List<Object?>> sheetRows,
    int targetSheetRowNumber, {
    int firstDataRowNumber = defaultFirstDataRowNumber,
  }) {
    final index = targetSheetRowNumber - firstDataRowNumber;
    if (index < 0 || index > sheetRows.length) return;
    sheetRows.insert(index, const []);
  }

  /// Removes a row from a local snapshot (for batch move/delete planning).
  static void removeRowAt(
    List<List<Object?>> sheetRows,
    int sheetRowNumber, {
    int firstDataRowNumber = defaultFirstDataRowNumber,
  }) {
    final index = sheetRowNumber - firstDataRowNumber;
    if (index < 0 || index >= sheetRows.length) return;
    sheetRows.removeAt(index);
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime? dateOnSheetRow(
    List<List<Object?>> sheetRows,
    int sheetRowNumber, {
    int firstDataRowNumber = defaultFirstDataRowNumber,
  }) {
    final index = sheetRowNumber - firstDataRowNumber;
    if (index < 0 || index >= sheetRows.length) return null;
    final row = sheetRows[index];
    return SheetParser.parseDate(
      row.isNotEmpty ? row[0] : null,
      row.length > 1 ? row[1] : null,
    );
  }
}
