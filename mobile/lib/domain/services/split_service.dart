import 'package:spendwise_mobile/data/models/models.dart';

class SplitService {
  /// Reserved id for the payer ("Me") in split UI and custom splits.
  static const selfParticipantId = '__self__';

  static int participantCount(List<String> contactIds) =>
      contactIds.length + 1;

  static double equalShare(double totalAmount, int participantCount) {
    if (participantCount <= 0) return 0;
    return double.parse(
      (totalAmount / participantCount).toStringAsFixed(2),
    );
  }

  /// Equal split among me + [contactIds]. Stores each contact's share.
  static Map<String, double> equalContactShares({
    required double totalAmount,
    required List<String> contactIds,
  }) {
    final share = equalShare(totalAmount, participantCount(contactIds));
    return {for (final id in contactIds) id: share};
  }

  static double myEqualShare({
    required double totalAmount,
    required List<String> contactIds,
  }) {
    return equalShare(totalAmount, participantCount(contactIds));
  }

  /// [participantIds] = [self, ...contacts]. Last id receives the remainder.
  static Map<String, double> customAmountsWithRemainder({
    required double totalAmount,
    required List<String> participantIds,
    required Map<String, double> enteredAmounts,
  }) {
    if (participantIds.isEmpty) return {};
    final result = <String, double>{};
    final autoId = participantIds.length >= 2 ? participantIds.last : null;
    var sum = 0.0;
    for (final id in participantIds) {
      if (id == autoId) continue;
      final amount = enteredAmounts[id] ?? 0;
      result[id] = amount;
      sum += amount;
    }
    if (autoId != null) {
      result[autoId] = double.parse((totalAmount - sum).toStringAsFixed(2));
    } else if (participantIds.length == 1) {
      result[participantIds.first] = totalAmount;
    }
    return result;
  }

  static bool customTotalsMatch({
    required double totalAmount,
    required Map<String, double> amounts,
  }) {
    final sum = amounts.values.fold(0.0, (a, b) => a + b);
    return (sum - totalAmount).abs() < 0.01 &&
        amounts.values.every((v) => v >= -0.001);
  }

  BillSplitModel createEqualSplit({
    required String id,
    required String transactionId,
    required double totalAmount,
    required List<String> contactIds,
    required String groupId,
  }) {
    if (contactIds.isEmpty) {
      throw ArgumentError('Select at least one group member');
    }
    if (groupId.isEmpty) {
      throw ArgumentError('Select a group');
    }
    return BillSplitModel(
      id: id,
      transactionId: transactionId,
      splitType: SplitType.equal,
      splitDetails: equalContactShares(
        totalAmount: totalAmount,
        contactIds: contactIds,
      ),
      groupId: groupId,
    );
  }

  BillSplitModel createCustomSplit({
    required String id,
    required String transactionId,
    required double totalAmount,
    required List<String> contactIds,
    required Map<String, double> enteredAmounts,
    required String groupId,
  }) {
    if (contactIds.isEmpty) {
      throw ArgumentError('Select at least one group member');
    }
    if (groupId.isEmpty) {
      throw ArgumentError('Select a group');
    }
    final participantIds = [selfParticipantId, ...contactIds];
    final amounts = customAmountsWithRemainder(
      totalAmount: totalAmount,
      participantIds: participantIds,
      enteredAmounts: enteredAmounts,
    );
    if (!customTotalsMatch(totalAmount: totalAmount, amounts: amounts)) {
      throw ArgumentError('Custom split must equal the expense total');
    }
    final contactOnly = Map<String, double>.from(amounts)
      ..remove(selfParticipantId);
    return BillSplitModel(
      id: id,
      transactionId: transactionId,
      splitType: SplitType.custom,
      splitDetails: contactOnly,
      groupId: groupId,
      myShare: amounts[selfParticipantId],
    );
  }

  String participantLabel(
    String participantId,
    Map<String, ContactModel> contactsById,
  ) {
    if (participantId == selfParticipantId) return 'Me';
    return contactsById[participantId]?.name ?? participantId;
  }

  String formatSplitDescription(
    BillSplitModel split,
    Map<String, ContactModel> contactsById, {
    double? totalAmount,
  }) {
    final parts = <String>[];
    if (split.splitType == SplitType.equal && totalAmount != null) {
      final share = myEqualShare(
        totalAmount: totalAmount,
        contactIds: split.splitDetails.keys.toList(),
      );
      parts.add('Me: ${share.toStringAsFixed(0)}');
    } else if (split.myShare != null) {
      parts.add('Me: ${split.myShare!.toStringAsFixed(0)}');
    }
    for (final e in split.splitDetails.entries) {
      final name = contactsById[e.key]?.name ?? e.key;
      parts.add('$name: ${e.value.toStringAsFixed(0)}');
    }
    return '[split: ${parts.join(', ')}]';
  }
}
