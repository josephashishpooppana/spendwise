import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/source_balance_calculator.dart';

void main() {
  group('SourceBalanceCalculator', () {
    test('net balance adds assets and subtracts credit card bills', () {
      const sources = [
        PaymentSourceModel(
          id: 'bank',
          name: 'ICICI',
          sourceTypeKey: 'BANK',
          balance: 50000,
        ),
        PaymentSourceModel(
          id: 'wallet',
          name: 'Paytm',
          sourceTypeKey: 'WALLET',
          balance: 2000,
        ),
        PaymentSourceModel(
          id: 'cc',
          name: 'Federal CC',
          sourceTypeKey: 'CREDIT_CARD',
          balance: 12000,
        ),
        PaymentSourceModel(
          id: 'dc',
          name: 'Debit',
          sourceTypeKey: 'DEBIT_CARD',
          balance: 50000,
          linkedBankSourceId: 'bank',
        ),
      ];

      expect(SourceBalanceCalculator.netTotalBalance(sources), 40000);
    });

    test('available credit uses limit minus bill', () {
      const card = PaymentSourceModel(
        id: 'cc',
        name: 'Federal CC',
        sourceTypeKey: 'CREDIT_CARD',
        balance: 12000,
        creditLimit: 50000,
      );

      expect(
        SourceBalanceCalculator.availableForExpense(card, {'cc': card}),
        38000,
      );
    });
  });
}
