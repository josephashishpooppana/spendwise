import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/balance_service.dart';
import 'package:spendwise_mobile/domain/services/split_balance_helper.dart';
import 'package:uuid/uuid.dart';

class SplitSettlementService {
  SplitSettlementService(
    this._db, {
    BalanceService? balanceService,
    Uuid? uuid,
  })  : _balanceService = balanceService ?? BalanceService(),
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final BalanceService _balanceService;
  final Uuid _uuid;

  Future<TransactionModel> markMemberPaid({
    required BillSplitModel split,
    required TransactionModel expense,
    required String contactId,
    required String contactName,
    required double amount,
    required String paymentSourceId,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than zero');
    }

    final existing = await _db.getSplitSettlementsForBillSplit(split.id);
    final remaining = SplitBalanceHelper.remainingForContact(
      split: split,
      settlements: existing,
      contactId: contactId,
    );
    if (amount > remaining + 0.01) {
      throw ArgumentError(
        'Amount exceeds remaining ${remaining.toStringAsFixed(2)}',
      );
    }

    final incomeId = _uuid.v4();
    final settlementId = _uuid.v4();
    final now = DateTime.now();

    final income = TransactionModel(
      id: incomeId,
      type: TransactionType.income,
      amount: amount,
      category: 'reimbursement',
      description: 'Split from $contactName · ${expense.description}',
      timestamp: now,
      paymentSourceId: paymentSourceId,
      notes: 'Split settlement for expense ${expense.id}',
      updatedAt: now,
    );

    await _db.insertTransaction(income);
    await _db.insertSplitSettlement(
      SplitSettlementModel(
        id: settlementId,
        billSplitId: split.id,
        contactId: contactId,
        amount: amount,
        paymentSourceId: paymentSourceId,
        incomeTransactionId: incomeId,
        paidAt: now,
      ),
    );

    final sources = await _db.getPaymentSources();
    final byId = {for (final s in sources) s.id: s.copyWith()};
    final source = byId[paymentSourceId];
    if (source != null) {
      _balanceService.applyDelta(
        source: source,
        amount: income.amount,
        type: income.type,
        sourcesById: byId,
        reverse: false,
      );
    }
    for (final source in byId.values) {
      await _db.updateSourceBalance(source.id, source.balance);
    }

    final allSettlements = await _db.getSplitSettlementsForBillSplit(split.id);
    final fullySettled = SplitBalanceHelper.isSplitFullySettled(
      split: split,
      settlements: allSettlements,
    );
    await _db.upsertBillSplit(
      split.copyWith(isSettled: fullySettled),
    );

    return income;
  }
}
