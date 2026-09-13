import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/sheet_column_letters.dart';
import 'package:spendwise_mobile/integrations/sheet_row_builder.dart';

void main() {
  test('indexToColumnLetter roundtrips with columnLetterToIndex', () {
    expect(
      SheetColumnLetters.indexToColumnLetter(
        SheetColumnLetters.columnLetterToIndex('AA'),
      ),
      'AA',
    );
    expect(
      SheetColumnLetters.indexToColumnLetter(
        SheetColumnLetters.columnLetterToIndex('BA'),
      ),
      'BA',
    );
  });

  test('mappingsFromSources uses stored sheet columns', () {
    const source = PaymentSourceModel(
      id: 's1',
      name: 'Union Bank',
      sourceTypeKey: 'BANK',
      sheetCreditColumn: 'BC',
      sheetDebitColumn: 'BD',
    );
    final mappings = SheetRowBuilder.mappingsFromSources([source]);
    expect(mappings.length, 1);
    expect(mappings.first.creditColumn, 'BC');
    expect(mappings.first.debitColumn, 'BD');
  });
}
