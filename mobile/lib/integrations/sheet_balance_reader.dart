import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/sheet_column_letters.dart';
import 'package:spendwise_mobile/integrations/sheet_parser.dart';

class PerSourceBalance {
  const PerSourceBalance({
    required this.amount,
    required this.sheetRowNumber,
  });

  final double amount;
  final int sheetRowNumber;
}

/// Reads running balances / bill totals from sheet rows (per account).
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

  /// Per-source last balance row: scans bottom-up for each account independently.
  static Map<String, PerSourceBalance> perSourceFromSheet({
    required List<List<Object?>> rows,
    required List<PaymentSourceModel> sources,
    int firstDataRowNumber = 3,
  }) {
    final result = <String, PerSourceBalance>{};
    for (final source in sources) {
      final reading = _findLastBalanceForSource(
        rows: rows,
        source: source,
        firstDataRowNumber: firstDataRowNumber,
      );
      if (reading != null) {
        result[source.id] = reading;
      }
    }
    return result;
  }

  static PerSourceBalance? _findLastBalanceForSource({
    required List<List<Object?>> rows,
    required PaymentSourceModel source,
    required int firstDataRowNumber,
  }) {
    final balanceCol = source.sheetBalanceColumn;
    if (balanceCol == null || balanceCol.isEmpty) return null;

    final balanceIdx = SheetColumnLetters.columnLetterToIndex(balanceCol);
    if (balanceIdx < 0) return null;

    final creditIdx = source.sheetCreditColumn != null
        ? SheetColumnLetters.columnLetterToIndex(source.sheetCreditColumn!)
        : -1;
    final debitIdx = source.sheetDebitColumn != null
        ? SheetColumnLetters.columnLetterToIndex(source.sheetDebitColumn!)
        : -1;

    PerSourceBalance? fallbackTxnRow;
    PerSourceBalance? fallbackAnyBalance;

    for (var i = rows.length - 1; i >= 0; i--) {
      final row = rows[i];
      final sheetRowNumber = firstDataRowNumber + i;

      final balance = balanceIdx < row.length
          ? SheetParser.parseAmountValue(row[balanceIdx])
          : null;
      final credit = creditIdx >= 0 && creditIdx < row.length
          ? SheetParser.parseAmountValue(row[creditIdx])
          : null;
      final debit = debitIdx >= 0 && debitIdx < row.length
          ? SheetParser.parseAmountValue(row[debitIdx])
          : null;

      if (balance != null) {
        fallbackAnyBalance ??=
            PerSourceBalance(amount: balance, sheetRowNumber: sheetRowNumber);
      }

      final hasCreditDebit =
          (credit != null && credit > 0) || (debit != null && debit > 0);
      if (hasCreditDebit && balance != null) {
        fallbackTxnRow ??=
            PerSourceBalance(amount: balance, sheetRowNumber: sheetRowNumber);
      }

      final desc =
          row.length > 2 ? row[2]?.toString().trim() ?? '' : '';
      final hasDescription = desc.isNotEmpty;

      if (balance != null && (!hasDescription || !hasCreditDebit)) {
        return PerSourceBalance(amount: balance, sheetRowNumber: sheetRowNumber);
      }
    }

    return fallbackTxnRow ?? fallbackAnyBalance;
  }

  /// Legacy helper: all sources from one global last dated row.
  static Map<String, double> fromLastSheetRow({
    required List<List<Object?>> rows,
    required List<PaymentSourceModel> sources,
    int firstDataRowNumber = 3,
  }) {
    final perSource = perSourceFromSheet(
      rows: rows,
      sources: sources,
      firstDataRowNumber: firstDataRowNumber,
    );
    return perSource.map((id, reading) => MapEntry(id, reading.amount));
  }

  static int sheetRowNumberForIndex(int rowIndex, int firstDataRowNumber) =>
      firstDataRowNumber + rowIndex;
}
