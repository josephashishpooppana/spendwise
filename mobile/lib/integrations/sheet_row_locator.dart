import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/sheet_column_letters.dart';
import 'package:spendwise_mobile/integrations/sheet_row_builder.dart';

/// Finds a sheet row for legacy synced transactions without row numbers.
class SheetRowLocator {
  static int? findRow({
    required TransactionModel txn,
    required PaymentSourceModel source,
    required List<List<Object?>> sheetRows,
    required int metadataStartColumnIndex,
    int firstDataRowNumber = 3,
  }) {
    if (!source.hasSheetMapping) return null;

    final amountColumn = SheetRowBuilder.amountColumnFor(
      transaction: txn,
      source: source,
    );
    if (amountColumn.isEmpty) return null;
    final amountIdx = SheetColumnLetters.columnLetterToIndex(amountColumn);
    final expectedAmount = txn.type == TransactionType.expense
        ? txn.netExpenseAmount
        : txn.amount;
    final expectedDate = SheetRowBuilder.excelSerialDate(txn.timestamp);
    final expectedDesc = txn.description.trim().toLowerCase();

    for (var i = 0; i < sheetRows.length; i++) {
      final row = sheetRows[i];
      if (row.length <= 2) continue;
      final desc = row[2]?.toString().trim().toLowerCase() ?? '';
      if (desc.isEmpty) continue;
      if (desc != expectedDesc && !desc.startsWith(expectedDesc)) continue;

      final rowDate = row.length > 1 ? row[1] : null;
      if (rowDate is num && (rowDate - expectedDate).abs() > 1) continue;

      final amount = row.length > amountIdx ? _asDouble(row[amountIdx]) : null;
      if (amount == null || (amount - expectedAmount).abs() > 0.02) continue;

      final txnId = row.length > metadataStartColumnIndex
          ? row[metadataStartColumnIndex]?.toString().trim()
          : null;
      if (txnId != null && txnId.isNotEmpty && txnId != txn.id) continue;

      return firstDataRowNumber + i;
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
