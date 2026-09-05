import 'package:spendwise_mobile/data/models/models.dart';

class SourceBalanceCalculator {
  SourceBalanceCalculator._();

  static double netTotalBalance(List<PaymentSourceModel> sources) {
    var total = 0.0;
    for (final s in sources) {
      switch (s.sourceTypeKey) {
        case 'DEBIT_CARD':
          break;
        case 'CREDIT_CARD':
          total -= s.balance;
        default:
          total += s.balance;
      }
    }
    return total;
  }

  static double availableForExpense(
    PaymentSourceModel source,
    Map<String, PaymentSourceModel> sourcesById,
  ) {
    switch (source.sourceTypeKey) {
      case 'CREDIT_CARD':
        if (source.creditLimit == null) return double.infinity;
        return source.creditLimit! - source.balance;
      case 'DEBIT_CARD':
        final bank = sourcesById[source.linkedBankSourceId];
        return bank?.balance ?? 0;
      default:
        return source.balance;
    }
  }

  static String availableLabel(PaymentSourceModel source) {
    switch (source.sourceTypeKey) {
      case 'CREDIT_CARD':
        final available = source.availableCredit;
        if (available != null) {
          return '${available.toStringAsFixed(0)} credit available';
        }
        return 'Bill ${source.balance.toStringAsFixed(0)}';
      case 'DEBIT_CARD':
        return 'Uses linked bank balance';
      default:
        return '${source.balance.toStringAsFixed(0)} available';
    }
  }
}
