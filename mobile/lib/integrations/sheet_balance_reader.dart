import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/sheet_column_letters.dart';
import 'package:spendwise_mobile/integrations/sheet_parser.dart';

/// Reads running balances / bill totals from the sheet's last data row.
class SheetBalanceReader {
  /// Finds the bottom-most row that looks like a transaction row (has a date).
  static int? findLastDataRowIndex(List<List<Object?>> rows) {
    for (var i = rows.length - 1; i >= 0; i--) {
      final row = rows[i];
      final date = SheetParser.parseDate(
        row.isNotEmpty ? row[0] : null,
        row.length > 1 ? row[1] : null,
      );
      if (date != null) return i;
    }
    for (var i = rows.length - 1; i >= 0; i--) {
      if (_rowHasNumericCells(rows[i])) return i;
    }
    return null;
  }

  static bool _rowHasNumericCells(List<Object?> row) {
    for (final cell in row) {
      if (SheetParser.parseAmountValue(cell) != null) return true;
    }
    return false;
  }

  /// Bank/cash [Balance] and credit card [Bill Total] from [sheetBalanceColumn].
  static Map<String, double> balancesForSources({
    required List<Object?> row,
    required List<PaymentSourceModel> sources,
  }) {
    final balances = <String, double>{};
    for (final source in sources) {
      final balanceCol = source.sheetBalanceColumn;
      if (balanceCol == null || balanceCol.isEmpty) continue;

      final idx = SheetColumnLetters.columnLetterToIndex(balanceCol);
      if (idx < 0 || idx >= row.length) continue;

      final value = SheetParser.parseAmountValue(row[idx]);
      if (value == null) continue;

      balances[source.id] = value;
    }
    return balances;
  }

  static Map<String, double> fromLastSheetRow({
    required List<List<Object?>> rows,
    required List<PaymentSourceModel> sources,
    int firstDataRowNumber = 3,
  }) {
    final rowIndex = findLastDataRowIndex(rows);
    if (rowIndex == null) return {};

    return balancesForSources(row: rows[rowIndex], sources: sources);
  }

  static int sheetRowNumberForIndex(int rowIndex, int firstDataRowNumber) =>
      firstDataRowNumber + rowIndex;
}
