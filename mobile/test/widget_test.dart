import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/domain/services/balance_service.dart';

void main() {
  test('SpendWise mobile package loads', () {
    expect(BalanceService(), isA<BalanceService>());
  });
}
