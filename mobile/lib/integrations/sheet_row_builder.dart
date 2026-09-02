import 'package:spendwise_mobile/data/models/models.dart';

/// Maps payment source names to Google Sheet column letters.
/// See docs/mobile/sheet-mapping.md
class SheetRowBuilder {
  static const defaultMappings = [
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
    SheetColumnMapping(
      sourceNamePattern: 'HDFC Bank Credit Card',
      creditColumn: 'Q',
      debitColumn: 'R',
    ),
    SheetColumnMapping(
      sourceNamePattern: 'HDFC',
      creditColumn: 'J',
      debitColumn: 'K',
    ),
    SheetColumnMapping(
      sourceNamePattern: 'Federal Bank Credit Card',
      creditColumn: 'N',
      debitColumn: 'O',
    ),
    SheetColumnMapping(
      sourceNamePattern: 'ICICI Bank Credit Card',
      creditColumn: 'T',
      debitColumn: 'U',
    ),
    SheetColumnMapping(
      sourceNamePattern: 'Cash In Hand',
      creditColumn: 'W',
      debitColumn: 'X',
    ),
  ];

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static SheetColumnMapping? findMapping(
    String sourceName, [
    List<SheetColumnMapping> mappings = defaultMappings,
  ]) {
    for (final m in mappings) {
      if (sourceName.contains(m.sourceNamePattern)) return m;
    }
    return null;
  }

  static double excelSerialDate(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    const epoch = DateTime.utc(1899, 12, 30);
    return utc.difference(epoch).inDays.toDouble();
  }

  /// Build a row for columns A through AS (45 columns).
  static List<Object?> buildRow({
    required TransactionModel transaction,
    required PaymentSourceModel source,
    String descriptionSuffix = '',
    List<SheetColumnMapping> mappings = defaultMappings,
  }) {
    const totalCols = 45; // A..AS
    final row = List<Object?>.filled(totalCols, '');

    final weekday = _weekdays[transaction.timestamp.weekday - 1];
    row[0] = weekday; // A
    row[1] = excelSerialDate(transaction.timestamp); // B
    row[2] = '${transaction.description}$descriptionSuffix'; // C

    final mapping = findMapping(source.name, mappings);
    if (mapping != null) {
      final colIndex = _columnLetterToIndex(
        transaction.type == TransactionType.income
            ? mapping.creditColumn
            : mapping.debitColumn,
      );
      final amount = transaction.type == TransactionType.expense
          ? transaction.netExpenseAmount
          : transaction.amount;
      if (colIndex >= 0 && colIndex < totalCols) {
        row[colIndex] = amount;
      }
    }

    return row;
  }

  static int _columnLetterToIndex(String letter) {
    var index = 0;
    for (var i = 0; i < letter.length; i++) {
      index = index * 26 + (letter.codeUnitAt(i) - 64);
    }
    return index - 1;
  }
}
