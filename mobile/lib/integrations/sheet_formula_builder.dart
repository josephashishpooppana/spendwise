import 'package:spendwise_mobile/data/models/models.dart';

/// Builds Google Sheets balance and summary formulas for inserted rows.
class SheetFormulaBuilder {
  SheetFormulaBuilder._();

  /// Bank / wallet / cash: previous balance − debit + credit.
  /// Credit card bill: previous bill + debit − credit (payment).
  static String balanceFormula({
    required int rowNumber,
    required PaymentSourceModel source,
  }) {
    if (rowNumber <= 1) return '';
    final bal = source.sheetBalanceColumn;
    final debit = source.sheetDebitColumn;
    final credit = source.sheetCreditColumn;
    if (bal == null || debit == null || credit == null) return '';

    final prev = rowNumber - 1;
    if (source.sourceTypeKey == 'CREDIT_CARD') {
      return '=$bal$prev+$debit$rowNumber-$credit$rowNumber';
    }
    return '=$bal$prev-$debit$rowNumber+$credit$rowNumber';
  }

  /// Sum of all [BANK] balance columns on [rowNumber].
  static String totalInBankFormula({
    required int rowNumber,
    required List<PaymentSourceModel> sources,
  }) {
    final cols = sources
        .where(
          (s) =>
              s.sourceTypeKey == 'BANK' &&
              s.sheetBalanceColumn != null &&
              s.sheetBalanceColumn!.isNotEmpty,
        )
        .map((s) => s.sheetBalanceColumn!)
        .toList();
    if (cols.isEmpty) return '';
    return '=${cols.map((c) => '$c$rowNumber').join('+')}';
  }

  /// Bank balances minus credit card bill totals (matches sheet Total Balance).
  static String totalBalanceFormula({
    required int rowNumber,
    required List<PaymentSourceModel> sources,
  }) {
    final bankCols = sources
        .where(
          (s) =>
              s.sourceTypeKey == 'BANK' &&
              s.sheetBalanceColumn != null &&
              s.sheetBalanceColumn!.isNotEmpty,
        )
        .map((s) => s.sheetBalanceColumn!)
        .toList();
    final ccCols = sources
        .where(
          (s) =>
              s.sourceTypeKey == 'CREDIT_CARD' &&
              s.sheetBalanceColumn != null &&
              s.sheetBalanceColumn!.isNotEmpty,
        )
        .map((s) => s.sheetBalanceColumn!)
        .toList();
    if (bankCols.isEmpty && ccCols.isEmpty) return '';

    final bankPart = bankCols.map((c) => '$c$rowNumber').join('+');
    final ccPart = ccCols.map((c) => '-$c$rowNumber').join('');
    if (bankPart.isEmpty) return '=$ccPart';
    if (ccPart.isEmpty) return '=$bankPart';
    return '=$bankPart$ccPart';
  }
}
