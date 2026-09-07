import 'package:spendwise_mobile/integrations/sheet_column_letters.dart';

/// Discovers Total In Bank / Total Balance column letters from row 1 headers.
class SheetSummaryColumns {
  SheetSummaryColumns._();

  static const defaultTotalInBank = 'M';
  static const defaultTotalBalance = 'Z';

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
}
