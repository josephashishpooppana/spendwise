import 'package:spendwise_mobile/data/models/models.dart';

class SplitBalanceHelper {
  SplitBalanceHelper._();

  static double paidAmount(
    List<SplitSettlementModel> settlements,
    String contactId,
  ) {
    return settlements
        .where((s) => s.contactId == contactId)
        .fold(0.0, (sum, s) => sum + s.amount);
  }

  static double owedAmount(BillSplitModel split, String contactId) {
    return split.splitDetails[contactId] ?? 0;
  }

  static double remainingForContact({
    required BillSplitModel split,
    required List<SplitSettlementModel> settlements,
    required String contactId,
  }) {
    final owed = owedAmount(split, contactId);
    final paid = paidAmount(settlements, contactId);
    final left = owed - paid;
    return left > 0.009 ? left : 0;
  }

  static double totalOutstanding({
    required BillSplitModel split,
    required List<SplitSettlementModel> settlements,
  }) {
    return split.splitDetails.keys.fold(
      0.0,
      (sum, contactId) =>
          sum +
          remainingForContact(
            split: split,
            settlements: settlements,
            contactId: contactId,
          ),
    );
  }

  static bool isContactFullyPaid({
    required BillSplitModel split,
    required List<SplitSettlementModel> settlements,
    required String contactId,
  }) {
    return remainingForContact(
          split: split,
          settlements: settlements,
          contactId: contactId,
        ) <
        0.01;
  }

  static bool isSplitFullySettled({
    required BillSplitModel split,
    required List<SplitSettlementModel> settlements,
  }) {
    return totalOutstanding(split: split, settlements: settlements) < 0.01;
  }
}
