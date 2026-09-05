import 'package:spendwise_mobile/integrations/sheet_parser.dart';
import 'package:spendwise_mobile/integrations/sheet_row_builder.dart';

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
  /// When [txnDate] is set, column A/B are filled so later inserts respect order.
  static void insertPlaceholderRowAt(
    List<List<Object?>> sheetRows,
    int targetSheetRowNumber, {
    DateTime? txnDate,
    int firstDataRowNumber = defaultFirstDataRowNumber,
  }) {
    final index = targetSheetRowNumber - firstDataRowNumber;
    if (index < 0 || index > sheetRows.length) return;

    if (txnDate == null) {
      sheetRows.insert(index, const []);
      return;
    }

    sheetRows.insert(index, _datePlaceholderRow(txnDate));
  }

  static List<Object?> _datePlaceholderRow(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return [
      weekdays[date.weekday - 1],
      SheetRowBuilder.excelSerialDate(date),
      '',
    ];
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
