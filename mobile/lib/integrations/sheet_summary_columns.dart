import 'package:spendwise_mobile/integrations/sheet_column_letters.dart';

/// Discovers sheet layout from row 1 headers (summary columns, metadata start).
class SheetSummaryColumns {
  SheetSummaryColumns._();

  static const defaultTotalInBank = 'M';
  static const defaultTotalBalance = 'Z';
  static const metadataHeader = 'Transaction ID';

  static ({String totalInBank, String totalBalance}) discover(
    List<Object?> headerRow,
  ) {
    var totalInBank = defaultTotalInBank;
    var totalBalance = defaultTotalBalance;

    for (var i = 0; i < headerRow.length; i++) {
      final header = headerRow[i]?.toString().trim() ?? '';
      if (header == 'Total In Bank') {
        totalInBank = SheetColumnLetters.indexToColumnLetter(i);
      } else if (header == 'Total Balance') {
        totalBalance = SheetColumnLetters.indexToColumnLetter(i);
      }
    }

    return (totalInBank: totalInBank, totalBalance: totalBalance);
  }

  /// 0-based index where metadata block starts, or null if header not found.
  static int? discoverMetadataStartColumn(List<Object?> headerRow) {
    for (var i = 0; i < headerRow.length; i++) {
      if (headerRow[i]?.toString().trim() == metadataHeader) {
        return i;
      }
    }
    return null;
  }
}
