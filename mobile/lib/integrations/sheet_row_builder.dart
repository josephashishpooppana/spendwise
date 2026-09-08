import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/split_service.dart';
import 'package:spendwise_mobile/integrations/sheet_column_letters.dart';
import 'package:spendwise_mobile/integrations/sheet_column_provisioner.dart';
import 'package:spendwise_mobile/integrations/sheet_formula_builder.dart';
import 'package:spendwise_mobile/integrations/sheet_range.dart';

/// Builds Google Sheet rows from app transactions.
/// See docs/mobile/sheet-mapping.md
class SheetRowBuilder {
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static List<SheetColumnMapping> mappingsFromSources(
    List<PaymentSourceModel> sources,
  ) =>
      sources
          .map((s) => s.toSheetMapping())
          .whereType<SheetColumnMapping>()
          .toList();

  static double excelSerialDate(DateTime date) {
    final utc = DateTime.utc(date.year, date.month, date.day);
    final epoch = DateTime.utc(1899, 12, 30);
    return utc.difference(epoch).inDays.toDouble();
  }

  static String amountColumnFor({
    required TransactionModel transaction,
    required PaymentSourceModel source,
  }) {
    if (!source.hasSheetMapping) return '';
    return transaction.type == TransactionType.income
        ? source.sheetCreditColumn!
        : source.sheetDebitColumn!;
  }

  static int totalColumnCount(int metadataStartColumnIndex) =>
      metadataStartColumnIndex + SheetColumnProvisioner.metadataFieldCount;

  static List<Object?> buildRow({
    required TransactionModel transaction,
    required PaymentSourceModel source,
    required int metadataStartColumnIndex,
    String descriptionSuffix = '',
    PaymentMethodModel? method,
    PaymentAppModel? app,
    BillSplitModel? split,
    GroupModel? group,
    Map<String, ContactModel> contactsById = const {},
    String? parentTransactionId,
    String? settlementContactId,
    String? settlementContactName,
    String syncSource = 'app',
  }) {
    final totalCols = totalColumnCount(metadataStartColumnIndex);
    final row = List<Object?>.filled(totalCols, '');

    final weekday = _weekdays[transaction.timestamp.weekday - 1];
    row[0] = weekday;
    row[1] = excelSerialDate(transaction.timestamp);
    row[2] = '${transaction.description}$descriptionSuffix';

    if (source.hasSheetMapping) {
      final amountColumn = amountColumnFor(
        transaction: transaction,
        source: source,
      );
      final colIndex = SheetColumnLetters.columnLetterToIndex(amountColumn);
      final amount = transaction.type == TransactionType.expense
          ? transaction.netExpenseAmount
          : transaction.amount;
      if (colIndex >= 0 && colIndex < totalCols) {
        row[colIndex] = amount;
      }
    }

    row[metadataStartColumnIndex + 0] = transaction.id;
    row[metadataStartColumnIndex + 1] =
        transaction.type == TransactionType.income ? 'Income' : 'Expense';
    row[metadataStartColumnIndex + 2] = transaction.category;
    row[metadataStartColumnIndex + 3] = transaction.amount;
    row[metadataStartColumnIndex + 4] = transaction.type == TransactionType.expense
        ? transaction.netExpenseAmount
        : transaction.amount;
    row[metadataStartColumnIndex + 5] =
        transaction.cashbackReceived > 0 ? transaction.cashbackReceived : '';
    row[metadataStartColumnIndex + 6] = source.id;
    row[metadataStartColumnIndex + 7] = source.name;
    row[metadataStartColumnIndex + 8] = source.sourceTypeKey;
    row[metadataStartColumnIndex + 9] = method?.id ?? '';
    row[metadataStartColumnIndex + 10] = method?.name ?? '';
    row[metadataStartColumnIndex + 11] = app?.id ?? '';
    row[metadataStartColumnIndex + 12] = app?.name ?? '';
    row[metadataStartColumnIndex + 13] = transaction.notes ?? '';
    row[metadataStartColumnIndex + 14] = parentTransactionId ?? '';
    row[metadataStartColumnIndex + 15] = split?.id ?? '';
    row[metadataStartColumnIndex + 16] = split?.splitType.name ?? '';
    row[metadataStartColumnIndex + 17] = split != null
        ? _splitSummary(split, contactsById, transaction.amount)
        : '';
    row[metadataStartColumnIndex + 18] =
        split != null ? (split.isSettled ? 'Yes' : 'No') : '';
    row[metadataStartColumnIndex + 19] = split != null
        ? split.splitDetails.entries
            .map((e) => '${e.key}:${e.value}')
            .join('|')
        : '';
    row[metadataStartColumnIndex + 20] = split != null
        ? (split.myShare ??
            (split.splitType == SplitType.equal
                ? SplitService.myEqualShare(
                    totalAmount: transaction.amount,
                    contactIds: split.splitDetails.keys.toList(),
                  )
                : transaction.amount -
                    split.splitDetails.values.fold(0.0, (a, b) => a + b)))
        : '';
    row[metadataStartColumnIndex + 21] = group?.id ?? split?.groupId ?? '';
    row[metadataStartColumnIndex + 22] = group?.name ?? '';
    row[metadataStartColumnIndex + 23] = settlementContactId ?? '';
    row[metadataStartColumnIndex + 24] = settlementContactName ?? '';
    row[metadataStartColumnIndex + 25] =
        (transaction.updatedAt ?? transaction.timestamp).toIso8601String();
    row[metadataStartColumnIndex + 26] = syncSource;

    return row;
  }

  static String _splitSummary(
    BillSplitModel split,
    Map<String, ContactModel> contactsById,
    double totalAmount,
  ) {
    final raw = SplitService().formatSplitDescription(
      split,
      contactsById,
      totalAmount: totalAmount,
    );
    return raw
        .replaceFirst('[split: ', '')
        .replaceFirst(']', '')
        .trim();
  }

  static List<sheets.ValueRange> buildUpdateRanges({
    required String sheetTitle,
    required int rowNumber,
    required List<Object?> fullRow,
    required String amountColumn,
    required int metadataStartColumnIndex,
    PaymentSourceModel? amountSource,
    String? clearAmountColumn,
  }) {
    final r = '$rowNumber';
    final metaStart = SheetColumnLetters.indexToColumnLetter(
      metadataStartColumnIndex,
    );
    final metaEnd = SheetColumnLetters.indexToColumnLetter(
      metadataStartColumnIndex + SheetColumnProvisioner.metadataFieldCount - 1,
    );
    final ranges = <sheets.ValueRange>[
      sheets.ValueRange(
        range: formatSheetRange(sheetTitle, 'A$r:C$r'),
        values: [
          [fullRow[0], fullRow[1], fullRow[2]],
        ],
      ),
      sheets.ValueRange(
        range: formatSheetRange(sheetTitle, '$metaStart$r:$metaEnd$r'),
        values: [
          fullRow.sublist(
            metadataStartColumnIndex,
            totalColumnCount(metadataStartColumnIndex),
          ),
        ],
      ),
    ];

    final columnsToClear = <String>{};
    if (clearAmountColumn != null &&
        clearAmountColumn.isNotEmpty &&
        clearAmountColumn != amountColumn) {
      columnsToClear.add(clearAmountColumn);
    }
    final sibling = siblingAmountColumn(
      source: amountSource,
      amountColumn: amountColumn,
    );
    if (sibling != null) {
      columnsToClear.add(sibling);
    }
    for (final col in columnsToClear) {
      ranges.add(
        sheets.ValueRange(
          range: formatSheetRange(sheetTitle, '$col$r'),
          values: [
            [''],
          ],
        ),
      );
    }

    if (amountColumn.isNotEmpty) {
      final colIndex = SheetColumnLetters.columnLetterToIndex(amountColumn);
      if (colIndex >= 0 && colIndex < fullRow.length) {
        ranges.add(
          sheets.ValueRange(
            range: formatSheetRange(sheetTitle, '$amountColumn$r'),
            values: [
              [fullRow[colIndex]],
            ],
          ),
        );
      }
    }

    return ranges;
  }

  /// Credit or debit sibling column for the same source (clears inherited values).
  static String? siblingAmountColumn({
    required PaymentSourceModel? source,
    required String amountColumn,
  }) {
    if (source == null || !source.hasSheetMapping || amountColumn.isEmpty) {
      return null;
    }
    final credit = source.sheetCreditColumn!;
    final debit = source.sheetDebitColumn!;
    if (amountColumn == credit) return debit;
    if (amountColumn == debit) return credit;
    return null;
  }

  static List<sheets.ValueRange> buildInsertRanges({
    required String sheetTitle,
    required int rowNumber,
    required List<Object?> fullRow,
    required String amountColumn,
    required int metadataStartColumnIndex,
    required PaymentSourceModel amountSource,
    required List<PaymentSourceModel> mappedSources,
    required String totalInBankColumn,
    required String totalBalanceColumn,
  }) {
    final ranges = buildUpdateRanges(
      sheetTitle: sheetTitle,
      rowNumber: rowNumber,
      fullRow: fullRow,
      amountColumn: amountColumn,
      metadataStartColumnIndex: metadataStartColumnIndex,
      amountSource: amountSource,
    );

    final r = '$rowNumber';
    for (final source in mappedSources) {
      if (!source.hasSheetMapping) continue;
      final formula = SheetFormulaBuilder.balanceFormula(
        rowNumber: rowNumber,
        source: source,
      );
      final col = source.sheetBalanceColumn;
      if (formula.isEmpty || col == null || col.isEmpty) continue;
      ranges.add(
        sheets.ValueRange(
          range: formatSheetRange(sheetTitle, '$col$r'),
          values: [
            [formula],
          ],
        ),
      );
    }

    final totalInBank = SheetFormulaBuilder.totalInBankFormula(
      rowNumber: rowNumber,
      sources: mappedSources,
    );
    if (totalInBank.isNotEmpty && totalInBankColumn.isNotEmpty) {
      ranges.add(
        sheets.ValueRange(
          range: formatSheetRange(sheetTitle, '$totalInBankColumn$r'),
          values: [
            [totalInBank],
          ],
        ),
      );
    }

    final totalBalance = SheetFormulaBuilder.totalBalanceFormula(
      rowNumber: rowNumber,
      sources: mappedSources,
    );
    if (totalBalance.isNotEmpty && totalBalanceColumn.isNotEmpty) {
      ranges.add(
        sheets.ValueRange(
          range: formatSheetRange(sheetTitle, '$totalBalanceColumn$r'),
          values: [
            [totalBalance],
          ],
        ),
      );
    }

    return ranges;
  }

  static int? parseStartRowFromUpdatedRange(String? updatedRange) {
    if (updatedRange == null || updatedRange.isEmpty) return null;
    final match = RegExp(r'!A(\d+)').firstMatch(updatedRange);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  @Deprecated('Use SheetColumnLetters.columnLetterToIndex')
  static int columnLetterToIndex(String letter) =>
      SheetColumnLetters.columnLetterToIndex(letter);
}
