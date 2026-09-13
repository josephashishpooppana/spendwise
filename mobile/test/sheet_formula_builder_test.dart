import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/sheet_formula_builder.dart';

void main() {
  group('SheetFormulaBuilder', () {
    const icici = PaymentSourceModel(
      id: 'icici',
      name: 'ICICI Bank',
      sourceTypeKey: 'BANK',
      sheetCreditColumn: 'D',
      sheetDebitColumn: 'E',
      sheetBalanceColumn: 'F',
    );
    const bob = PaymentSourceModel(
      id: 'bob',
      name: 'BOB',
      sourceTypeKey: 'BANK',
      sheetCreditColumn: 'G',
      sheetDebitColumn: 'H',
      sheetBalanceColumn: 'I',
    );
    const hdfc = PaymentSourceModel(
      id: 'hdfc',
      name: 'HDFC',
      sourceTypeKey: 'BANK',
      sheetCreditColumn: 'J',
      sheetDebitColumn: 'K',
      sheetBalanceColumn: 'L',
    );
    const federalCc = PaymentSourceModel(
      id: 'federal',
      name: 'Federal CC',
      sourceTypeKey: 'CREDIT_CARD',
      sheetCreditColumn: 'N',
      sheetDebitColumn: 'O',
      sheetBalanceColumn: 'P',
    );
    const hdfcCc = PaymentSourceModel(
      id: 'hdfc-cc',
      name: 'HDFC CC',
      sourceTypeKey: 'CREDIT_CARD',
      sheetCreditColumn: 'Q',
      sheetDebitColumn: 'R',
      sheetBalanceColumn: 'S',
    );
    const iciciCc = PaymentSourceModel(
      id: 'icici-cc',
      name: 'ICICI CC',
      sourceTypeKey: 'CREDIT_CARD',
      sheetCreditColumn: 'T',
      sheetDebitColumn: 'U',
      sheetBalanceColumn: 'V',
    );

    const sources = [icici, bob, hdfc, federalCc, hdfcCc, iciciCc];

    test('bank balance formula for row 1852', () {
      expect(
        SheetFormulaBuilder.balanceFormula(rowNumber: 1852, source: icici),
        '=F1851-E1852+D1852',
      );
    });

    test('credit card bill formula for row 1852', () {
      expect(
        SheetFormulaBuilder.balanceFormula(rowNumber: 1852, source: federalCc),
        '=P1851+O1852-N1852',
      );
    });

    test('total in bank sums bank balance columns', () {
      expect(
        SheetFormulaBuilder.totalInBankFormula(rowNumber: 1852, sources: sources),
        '=F1852+I1852+L1852',
      );
    });

    test('total balance is banks minus credit card bills', () {
      expect(
        SheetFormulaBuilder.totalBalanceFormula(
          rowNumber: 1852,
          sources: sources,
        ),
        '=F1852+I1852+L1852-P1852-S1852-V1852',
      );
    });
  });
}
