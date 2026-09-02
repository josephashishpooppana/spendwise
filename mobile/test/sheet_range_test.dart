import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/integrations/sheet_range.dart';

void main() {
  test('formatSheetRange leaves simple titles unquoted', () {
    expect(formatSheetRange('Sheet1', 'A3:AS'), 'Sheet1!A3:AS');
  });

  test('formatSheetRange quotes titles with spaces', () {
    expect(
      formatSheetRange('Copy of Sheet1', 'A:AS'),
      "'Copy of Sheet1'!A:AS",
    );
  });
}
