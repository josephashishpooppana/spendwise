import 'package:spendwise_mobile/data/models/models.dart';

/// Applies balance deltas matching backend `_apply_transaction_to_source_balance`.
class BalanceService {
  double applyDelta({
    required PaymentSourceModel source,
    required double amount,
    required TransactionType type,
    required Map<String, PaymentSourceModel> sourcesById,
    bool reverse = false,
  }) {
    if (amount == 0) return source.balance;

    final normalized = type == TransactionType.income
        ? (reverse ? -amount : amount)
        : (reverse ? amount : -amount);

    var newBalance = source.balance + normalized;
    sourcesById[source.id] = source.copyWith(balance: newBalance);

    if (source.sourceTypeKey == 'DEBIT_CARD' &&
        source.linkedBankSourceId != null) {
      final bank = sourcesById[source.linkedBankSourceId!];
      if (bank != null) {
        final bankBalance = bank.balance + normalized;
        sourcesById[bank.id] = bank.copyWith(balance: bankBalance);
      }
    }

    return newBalance;
  }
}
