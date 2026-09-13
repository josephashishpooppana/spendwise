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
      final reading = balanceForSource(
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

  /// Best balance reading for one source (cash/wallet use activity row first).
  static PerSourceBalance? balanceForSource({
    required List<List<Object?>> rows,
    required PaymentSourceModel source,
    int firstDataRowNumber = 3,
    int? preferSheetRowNumber,
  }) {
    if (_isCashLike(source)) {
      final fromActivity = _balanceFromLastActivityRow(
        rows: rows,
        source: source,
        firstDataRowNumber: firstDataRowNumber,
      );
      if (fromActivity != null) return fromActivity;

      if (preferSheetRowNumber != null) {
        final fromRow = _balanceOnSheetRow(
          rows: rows,
          source: source,
          sheetRowNumber: preferSheetRowNumber,
          firstDataRowNumber: firstDataRowNumber,
        );
        if (fromRow != null) return fromRow;
      }
    }

    return _scanBottomUpForBalance(
      rows: rows,
      source: source,
      firstDataRowNumber: firstDataRowNumber,
    );
  }

  static bool _isCashLike(PaymentSourceModel source) =>
      source.sourceTypeKey == 'CASH' || source.sourceTypeKey == 'WALLET';

  static PerSourceBalance? _balanceOnSheetRow({
    required List<List<Object?>> rows,
    required PaymentSourceModel source,
    required int sheetRowNumber,
    required int firstDataRowNumber,
  }) {
    final idx = sheetRowNumber - firstDataRowNumber;
    if (idx < 0 || idx >= rows.length) return null;
    final amounts = balancesForSources(row: rows[idx], sources: [source]);
    final amount = amounts[source.id];
    if (amount == null) return null;
    return PerSourceBalance(amount: amount, sheetRowNumber: sheetRowNumber);
  }

  /// Last row with description + credit/debit for this source and a balance value.
  static PerSourceBalance? _balanceFromLastActivityRow({
    required List<List<Object?>> rows,
    required PaymentSourceModel source,
    required int firstDataRowNumber,
  }) {
    final cells = _sourceColumnIndices(source);
    if (cells == null) return null;

    for (var i = rows.length - 1; i >= 0; i--) {
      final row = rows[i];
      final sheetRowNumber = firstDataRowNumber + i;
      final reading = _readRowCells(row, cells);

      if (!reading.hasDescription && reading.hasCreditDebit) {
        continue;
      }
      if (reading.hasDescription &&
          reading.hasCreditDebit &&
          reading.balance != null) {
        return PerSourceBalance(
          amount: reading.balance!,
          sheetRowNumber: sheetRowNumber,
        );
      }
    }
    return null;
  }

  static PerSourceBalance? _scanBottomUpForBalance({
    required List<List<Object?>> rows,
    required PaymentSourceModel source,
    required int firstDataRowNumber,
  }) {
    final cells = _sourceColumnIndices(source);
    if (cells == null) return null;

    PerSourceBalance? fallbackAnyBalance;

    for (var i = rows.length - 1; i >= 0; i--) {
      final row = rows[i];
      final sheetRowNumber = firstDataRowNumber + i;
      final reading = _readRowCells(row, cells);

      if (reading.balance != null) {
        fallbackAnyBalance ??= PerSourceBalance(
          amount: reading.balance!,
          sheetRowNumber: sheetRowNumber,
        );
      }

      if (reading.balance == null) continue;

      // Blank row with inherited credit/debit from sheet insert — skip.
      if (!reading.hasDescription && reading.hasCreditDebit) continue;

      return PerSourceBalance(
        amount: reading.balance!,
        sheetRowNumber: sheetRowNumber,
      );
    }

    return fallbackAnyBalance;
  }

  static _RowCellReading _readRowCells(
    List<Object?> row,
    _SourceColumnIndices cells,
  ) {
    final balance = cells.balanceIdx >= 0 && cells.balanceIdx < row.length
        ? SheetParser.parseAmountValue(row[cells.balanceIdx])
        : null;
    final credit = cells.creditIdx >= 0 && cells.creditIdx < row.length
        ? SheetParser.parseAmountValue(row[cells.creditIdx])
        : null;
    final debit = cells.debitIdx >= 0 && cells.debitIdx < row.length
        ? SheetParser.parseAmountValue(row[cells.debitIdx])
        : null;
    final desc = row.length > 2 ? row[2]?.toString().trim() ?? '' : '';

    return _RowCellReading(
      balance: balance,
      hasCreditDebit:
          (credit != null && credit > 0) || (debit != null && debit > 0),
      hasDescription: desc.isNotEmpty,
    );
  }

  static _SourceColumnIndices? _sourceColumnIndices(PaymentSourceModel source) {
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

    return _SourceColumnIndices(
      balanceIdx: balanceIdx,
      creditIdx: creditIdx,
      debitIdx: debitIdx,
    );
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

class _SourceColumnIndices {
  const _SourceColumnIndices({
    required this.balanceIdx,
    required this.creditIdx,
    required this.debitIdx,
  });

  final int balanceIdx;
  final int creditIdx;
  final int debitIdx;
}

class _RowCellReading {
  const _RowCellReading({
    required this.balance,
    required this.hasCreditDebit,
    required this.hasDescription,
  });

  final double? balance;
  final bool hasCreditDebit;
  final bool hasDescription;
}
