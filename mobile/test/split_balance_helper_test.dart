import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/split_balance_helper.dart';

void main() {
  test('total outstanding subtracts settlements', () {
    const split = BillSplitModel(
      id: 's1',
      transactionId: 't1',
      splitType: SplitType.equal,
      splitDetails: {'c1': 50, 'c2': 50},
    );
    const settlements = [
      SplitSettlementModel(
        id: 'x1',
        billSplitId: 's1',
        contactId: 'c1',
        amount: 50,
        paymentSourceId: 'bank',
        incomeTransactionId: 'i1',
        paidAt: DateTime(2026, 1, 1),
      ),
    ];

    expect(
      SplitBalanceHelper.totalOutstanding(
        split: split,
        settlements: settlements,
      ),
      50,
    );
  });
}
