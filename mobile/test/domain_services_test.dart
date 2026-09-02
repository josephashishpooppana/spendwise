import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/balance_service.dart';
import 'package:spendwise_mobile/domain/services/cashback_service.dart';

void main() {
  group('BalanceService', () {
    test('income increases source balance', () {
      final service = BalanceService();
      final source = PaymentSourceModel(
        id: 's1',
        name: 'ICICI Bank',
        sourceTypeKey: 'BANK',
        balance: 1000,
      );
      final map = {'s1': source};

      service.applyDelta(
        source: source,
        amount: 500,
        type: TransactionType.income,
        sourcesById: map,
      );

      expect(map['s1']!.balance, 1500);
    });

    test('expense decreases source balance', () {
      final service = BalanceService();
      final source = PaymentSourceModel(
        id: 's1',
        name: 'ICICI Bank',
        sourceTypeKey: 'BANK',
        balance: 1000,
      );
      final map = {'s1': source};

      service.applyDelta(
        source: source,
        amount: 200,
        type: TransactionType.expense,
        sourcesById: map,
      );

      expect(map['s1']!.balance, 800);
    });

    test('debit card mirrors delta to linked bank', () {
      final service = BalanceService();
      final bank = PaymentSourceModel(
        id: 'bank',
        name: 'HDFC',
        sourceTypeKey: 'BANK',
        balance: 5000,
      );
      final card = PaymentSourceModel(
        id: 'card',
        name: 'HDFC Debit',
        sourceTypeKey: 'DEBIT_CARD',
        balance: 5000,
        linkedBankSourceId: 'bank',
      );
      final map = {'bank': bank, 'card': card};

      service.applyDelta(
        source: card,
        amount: 100,
        type: TransactionType.expense,
        sourcesById: map,
      );

      expect(map['card']!.balance, 4900);
      expect(map['bank']!.balance, 4900);
    });
  });

  group('CashbackService', () {
    test('fixed cashback creates income transaction', () {
      final service = CashbackService();
      final expense = TransactionModel(
        id: 'e1',
        type: TransactionType.expense,
        amount: 1000,
        category: 'groceries',
        description: 'BigBasket',
        timestamp: DateTime(2026, 2, 19),
        paymentSourceId: 's1',
      );

      final result = service.processEntries(
        expense: expense,
        entries: const [
          CashbackEntryInput(kind: CashbackKind.fixed, amount: 45),
        ],
        defaultCreditSourceId: 's1',
      );

      expect(result.totalCashback, 45);
      expect(result.incomeTransactions.length, 1);
      expect(result.incomeTransactions.first.amount, 45);
      expect(result.incomeTransactions.first.category, 'cashback');
    });

    test('percentage cashback computes amount', () {
      final service = CashbackService();
      final expense = TransactionModel(
        id: 'e1',
        type: TransactionType.expense,
        amount: 200,
        category: 'transport',
        description: 'Uber',
        timestamp: DateTime(2026, 2, 19),
        paymentSourceId: 's1',
      );

      final result = service.processEntries(
        expense: expense,
        entries: const [
          CashbackEntryInput(kind: CashbackKind.percentage, percentage: 5),
        ],
        defaultCreditSourceId: 's1',
      );

      expect(result.totalCashback, 10);
    });

    test('reward points do not create income transaction', () {
      final service = CashbackService();
      final expense = TransactionModel(
        id: 'e1',
        type: TransactionType.expense,
        amount: 500,
        category: 'shopping',
        description: 'Amazon',
        timestamp: DateTime(2026, 2, 19),
        paymentSourceId: 's1',
        paymentAppId: 'app1',
      );

      final result = service.processEntries(
        expense: expense,
        entries: const [
          CashbackEntryInput(
            kind: CashbackKind.rewardPoints,
            rewardPoints: 100,
            rewardAppId: 'app1',
          ),
        ],
        defaultCreditSourceId: 's1',
      );

      expect(result.incomeTransactions, isEmpty);
      expect(result.cashbacks.first.rewardPoints, 100);
    });
  });
}
