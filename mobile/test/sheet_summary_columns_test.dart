import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/integrations/sheet_summary_columns.dart';

void main() {
  test('discovers Total In Bank and Total Balance columns', () {
    final headerRow = List<Object?>.filled(26, '');
    headerRow[12] = 'Total In Bank';
    headerRow[25] = 'Total Balance';

    final result = SheetSummaryColumns.discover(headerRow);
    expect(result.totalInBank, 'M');
    expect(result.totalBalance, 'Z');
  });

  test('falls back to M and Z when headers missing', () {
    final result = SheetSummaryColumns.discover(const []);
    expect(result.totalInBank, 'M');
    expect(result.totalBalance, 'Z');
  });
}
