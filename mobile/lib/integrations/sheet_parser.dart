import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/sheet_column_letters.dart';

/// One income or expense parsed from a single sheet cell.
class ParsedSheetTransaction {
  const ParsedSheetTransaction({
    required this.sheetRowNumber,
    required this.date,
    required this.description,
    required this.type,
    required this.amount,
    required this.sourceNamePattern,
    required this.columnKey,
    this.metadata = const SheetImportMetadata.empty(),
  });

  final int sheetRowNumber;
  final DateTime date;
  final String description;
  final TransactionType type;
  final double amount;
  final String sourceNamePattern;
  final String columnKey;
  final SheetImportMetadata metadata;

  String get importId {
    if (metadata.transactionId.isNotEmpty) {
      return metadata.transactionId;
    }
    return 'sheet-$sheetRowNumber-$columnKey-${amount.toStringAsFixed(2)}';
  }
}

class SheetImportMetadata {
  const SheetImportMetadata({
    required this.transactionId,
    required this.typeLabel,
    required this.category,
    required this.grossAmount,
    required this.netAmount,
    required this.cashback,
    required this.sourceId,
    required this.sourceName,
    required this.sourceType,
    required this.methodId,
    required this.methodName,
    required this.appId,
    required this.appName,
    required this.notes,
    required this.parentTransactionId,
    required this.syncSource,
  });

  const SheetImportMetadata.empty()
      : transactionId = '',
        typeLabel = '',
        category = 'unknown',
        grossAmount = null,
        netAmount = null,
        cashback = null,
        sourceId = '',
        sourceName = '',
        sourceType = '',
        methodId = '',
        methodName = '',
        appId = '',
        appName = '',
        notes = '',
        parentTransactionId = '',
        syncSource = 'sheet';

  final String transactionId;
  final String typeLabel;
  final String category;
  final double? grossAmount;
  final double? netAmount;
  final double? cashback;
  final String sourceId;
  final String sourceName;
  final String sourceType;
  final String methodId;
  final String methodName;
  final String appId;
  final String appName;
  final String notes;
  final String parentTransactionId;
  final String syncSource;

  static const unknown = 'unknown';

  static SheetImportMetadata fromRow(
    List<Object?> row, {
    required int metadataStartColumnIndex,
  }) {
    String cell(int offset) {
      final idx = metadataStartColumnIndex + offset;
      if (idx < 0 || idx >= row.length) return '';
      final v = row[idx];
      if (v == null) return '';
      return v.toString().trim();
    }

    double? amountAt(int offset) {
      final text = cell(offset);
      if (text.isEmpty) return null;
      return double.tryParse(text.replaceAll(',', ''));
    }

    String unknownIfEmpty(String value) =>
        value.isEmpty ? unknown : value;

    return SheetImportMetadata(
      transactionId: cell(0),
      typeLabel: cell(1),
      category: unknownIfEmpty(cell(2)),
      grossAmount: amountAt(3),
      netAmount: amountAt(4),
      cashback: amountAt(5),
      sourceId: cell(6),
      sourceName: cell(7),
      sourceType: unknownIfEmpty(cell(8)),
      methodId: cell(9),
      methodName: unknownIfEmpty(cell(10)),
      appId: cell(11),
      appName: unknownIfEmpty(cell(12)),
      notes: cell(13),
      parentTransactionId: cell(14),
      syncSource: cell(26).isEmpty ? 'sheet' : cell(26),
    );
  }
}

class SheetParser {
  static final _epoch = DateTime.utc(1899, 12, 30);

  /// Parse all data rows (sheet row numbers are 1-based, first data row = 3).
  static List<ParsedSheetTransaction> parseAllRows(
    List<List<Object?>> rows, {
    int firstDataRowNumber = 3,
    required List<SheetColumnMapping> mappings,
    required int metadataStartColumnIndex,
  }) {
    final parsed = <ParsedSheetTransaction>[];
    for (var i = 0; i < rows.length; i++) {
      parsed.addAll(
        parseRow(
          rows[i],
          sheetRowNumber: firstDataRowNumber + i,
          mappings: mappings,
          metadataStartColumnIndex: metadataStartColumnIndex,
        ),
      );
    }
    parsed.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.sheetRowNumber.compareTo(b.sheetRowNumber);
    });
    return parsed;
  }

  static List<ParsedSheetTransaction> parseRow(
    List<Object?> row, {
    required int sheetRowNumber,
    required List<SheetColumnMapping> mappings,
    required int metadataStartColumnIndex,
  }) {
    final date = parseDate(row.isNotEmpty ? row[0] : null, row.length > 1 ? row[1] : null);
    if (date == null) return const [];

    final rawDesc = cellString(row, 2);
    final description = cleanDescription(rawDesc);
    if (description.isEmpty) return const [];

    final metadata = SheetImportMetadata.fromRow(
      row,
      metadataStartColumnIndex: metadataStartColumnIndex,
    );
    final results = <ParsedSheetTransaction>[];

    for (final mapping in mappings) {
      final creditIdx =
          SheetColumnLetters.columnLetterToIndex(mapping.creditColumn);
      final debitIdx =
          SheetColumnLetters.columnLetterToIndex(mapping.debitColumn);

      final credit = parseAmount(row, creditIdx);
      if (credit != null && credit > 0) {
        results.add(
          ParsedSheetTransaction(
            sheetRowNumber: sheetRowNumber,
            date: date,
            description: description,
            type: TransactionType.income,
            amount: credit,
            sourceNamePattern: mapping.sourceNamePattern,
            columnKey: mapping.creditColumn,
            metadata: metadata,
          ),
        );
      }

      final debit = parseAmount(row, debitIdx);
      if (debit != null && debit > 0) {
        results.add(
          ParsedSheetTransaction(
            sheetRowNumber: sheetRowNumber,
            date: date,
            description: description,
            type: TransactionType.expense,
            amount: debit,
            sourceNamePattern: mapping.sourceNamePattern,
            columnKey: mapping.debitColumn,
            metadata: metadata,
          ),
        );
      }
    }

    return results;
  }

  /// Column A may hold weekday; column B holds Excel serial or date string.
  static DateTime? parseDate(Object? colA, Object? colB) {
    final fromB = _parseDateValue(colB);
    if (fromB != null) return fromB;
    return _parseDateValue(colA);
  }

  static DateTime? _parseDateValue(Object? value) {
    if (value == null) return null;
    if (value is DateTime) {
      return DateTime(value.year, value.month, value.day);
    }
    if (value is num) {
      return _epoch.add(Duration(days: value.floor()));
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final asNum = double.tryParse(text);
    if (asNum != null && asNum > 1000) {
      return _epoch.add(Duration(days: asNum.floor()));
    }
    final iso = DateTime.tryParse(text);
    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day);
    }

    final slashParts = text.split('/');
    if (slashParts.length == 3) {
      final d1 = int.tryParse(slashParts[0].trim());
      final d2 = int.tryParse(slashParts[1].trim());
      final y = int.tryParse(slashParts[2].trim());
      if (d1 != null && d2 != null && y != null) {
        // Prefer DD/MM/YYYY (common in India), fall back to MM/DD/YYYY.
        if (d1 > 12) {
          return DateTime(y, d2, d1);
        }
        if (d2 > 12) {
          return DateTime(y, d1, d2);
        }
        return DateTime(y, d2, d1);
      }
    }

    final dashParts = text.split('-');
    if (dashParts.length == 3) {
      final d1 = int.tryParse(dashParts[0].trim());
      final d2 = int.tryParse(dashParts[1].trim());
      final y = int.tryParse(dashParts[2].trim());
      if (d1 != null && d2 != null && y != null && y > 1900) {
        if (d1 > 12) {
          return DateTime(y, d2, d1);
        }
        if (d2 > 12) {
          return DateTime(y, d1, d2);
        }
        return DateTime(y, d2, d1);
      }
    }

    return null;
  }

  static double? parseAmount(List<Object?> row, int index) {
    if (index < 0 || index >= row.length) return null;
    return parseAmountValue(row[index]);
  }

  static double? parseAmountValue(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final cleaned = text.replaceAll(',', '').replaceAll('₹', '').trim();
    return double.tryParse(cleaned);
  }

  static String cellString(List<Object?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    final v = row[index];
    if (v == null) return '';
    return v.toString().trim();
  }

  static String cleanDescription(String raw) {
    var desc = raw.trim();
    for (final suffix in [' [cashback]', ' [split:']) {
      final idx = desc.indexOf(suffix);
      if (idx > 0) desc = desc.substring(0, idx).trim();
    }
    return desc;
  }

  static String inferCategory(ParsedSheetTransaction entry) {
    if (entry.metadata.category != SheetImportMetadata.unknown) {
      return entry.metadata.category;
    }
    final lower = entry.description.toLowerCase();
    if (entry.type == TransactionType.income) {
      if (lower.startsWith('cashback') || lower.contains('cashback')) {
        return 'cashback';
      }
      if (lower.contains('salary')) return 'salary';
      if (lower.contains('refund')) return 'refund';
      if (lower.contains('interest')) return 'investment_returns';
      return 'other';
    }
    if (lower.contains('grocery') || lower.contains('bigbasket')) {
      return 'groceries';
    }
    if (lower.contains('uber') || lower.contains('bus') || lower.contains('metro')) {
      return 'transport';
    }
    if (lower.contains('food') || lower.contains('lunch') || lower.contains('biriyani')) {
      return 'food_dining';
    }
    if (lower.contains('bill') || lower.contains('recharge') || lower.contains('broadband')) {
      return 'utilities';
    }
    return 'other';
  }

  static PaymentSourceModel? matchSource(
    String sourceNamePattern,
    List<PaymentSourceModel> sources,
  ) {
    for (final s in sources) {
      if (s.name.contains(sourceNamePattern) ||
          sourceNamePattern.contains(s.name)) {
        return s;
      }
    }
    for (final s in sources) {
      if (s.name.toLowerCase().contains(sourceNamePattern.toLowerCase())) {
        return s;
      }
    }
    return null;
  }

  static String defaultMethodIdForSource(PaymentSourceModel source) {
    switch (source.sourceTypeKey) {
      case 'CREDIT_CARD':
        return 'pm-cc';
      case 'CASH':
        return 'pm-cash';
      case 'WALLET':
        return 'pm-wallet';
      case 'DEBIT_CARD':
        return 'pm-dc';
      default:
        return 'pm-other';
    }
  }
}

class SheetImportResult {
  const SheetImportResult({
    required this.success,
    required this.message,
    this.imported = 0,
    this.skipped = 0,
    this.unmatchedSources = const {},
  });

  final bool success;
  final String message;
  final int imported;
  final int skipped;
  final Set<String> unmatchedSources;
}
