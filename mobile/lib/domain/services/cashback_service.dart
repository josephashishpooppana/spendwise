import 'package:spendwise_mobile/data/models/models.dart';
import 'package:uuid/uuid.dart';

class CashbackEntryInput {
  const CashbackEntryInput({
    required this.kind,
    this.amount,
    this.percentage,
    this.rewardPoints,
    this.creditSourceId,
    this.rewardAppId,
  });

  final CashbackKind kind;
  final double? amount;
  final double? percentage;
  final int? rewardPoints;
  final String? creditSourceId;
  final String? rewardAppId;
}

class CashbackProcessResult {
  const CashbackProcessResult({
    required this.cashbacks,
    required this.incomeTransactions,
    required this.totalCashback,
  });

  final List<CashbackModel> cashbacks;
  final List<TransactionModel> incomeTransactions;
  final double totalCashback;
}

/// Mirrors backend `_create_cashback_for_expense` / `_create_single_cashback_entry`.
class CashbackService {
  CashbackService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  CashbackProcessResult processEntries({
    required TransactionModel expense,
    required List<CashbackEntryInput> entries,
    required String defaultCreditSourceId,
  }) {
    final cashbacks = <CashbackModel>[];
    final incomeTransactions = <TransactionModel>[];
    var total = 0.0;

    for (final entry in entries) {
      final result = _createSingle(
        expense: expense,
        entry: entry,
        defaultCreditSourceId: defaultCreditSourceId,
      );
      if (result == null) continue;
      cashbacks.add(result.cashback);
      total += result.cashback.amount;
      if (result.incomeTransaction != null) {
        incomeTransactions.add(result.incomeTransaction!);
      }
    }

    return CashbackProcessResult(
      cashbacks: cashbacks,
      incomeTransactions: incomeTransactions,
      totalCashback: total,
    );
  }

  _SingleResult? _createSingle({
    required TransactionModel expense,
    required CashbackEntryInput entry,
    required String defaultCreditSourceId,
  }) {
    var amount = 0.0;
    double? percentage;
    int? rewardPoints;

    switch (entry.kind) {
      case CashbackKind.fixed:
        amount = entry.amount ?? 0;
      case CashbackKind.percentage:
        percentage = entry.percentage ?? 0;
        amount = double.parse(
          (expense.amount * percentage / 100).toStringAsFixed(2),
        );
      case CashbackKind.rewardPoints:
        rewardPoints = entry.rewardPoints ?? 0;
    }

    if (entry.kind == CashbackKind.rewardPoints && rewardPoints <= 0) {
      return null;
    }
    if (entry.kind != CashbackKind.rewardPoints && amount <= 0) {
      return null;
    }

    final creditSourceId = entry.creditSourceId ?? defaultCreditSourceId;
    TransactionModel? incomeTxn;

    if (entry.kind != CashbackKind.rewardPoints && amount > 0) {
      incomeTxn = TransactionModel(
        id: _uuid.v4(),
        type: TransactionType.income,
        amount: amount,
        category: 'cashback',
        description: 'Cashback: ${expense.description}',
        timestamp: expense.timestamp,
        paymentSourceId: creditSourceId,
        cashbackFromExpenseId: expense.id,
      );
    }

    final cashback = CashbackModel(
      id: _uuid.v4(),
      transactionId: expense.id,
      kind: entry.kind,
      amount: amount,
      percentage: percentage,
      rewardPoints: rewardPoints,
      creditSourceId:
          entry.kind == CashbackKind.rewardPoints ? null : creditSourceId,
      rewardAppId: entry.rewardAppId,
      incomeTransactionId: incomeTxn?.id,
    );

    return _SingleResult(cashback: cashback, incomeTransaction: incomeTxn);
  }
}

class _SingleResult {
  const _SingleResult({required this.cashback, this.incomeTransaction});

  final CashbackModel cashback;
  final TransactionModel? incomeTransaction;
}
