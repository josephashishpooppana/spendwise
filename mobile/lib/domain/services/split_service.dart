import 'package:spendwise_mobile/data/models/models.dart';

class SplitService {
  BillSplitModel createEqualSplit({
    required String id,
    required String transactionId,
    required double totalAmount,
    required List<String> contactIds,
    String? groupId,
  }) {
    if (contactIds.isEmpty) {
      throw ArgumentError('At least one contact required');
    }
    final share = double.parse(
      (totalAmount / contactIds.length).toStringAsFixed(2),
    );
    return BillSplitModel(
      id: id,
      transactionId: transactionId,
      splitType: SplitType.equal,
      splitDetails: {for (final c in contactIds) c: share},
      groupId: groupId,
    );
  }

  BillSplitModel createCustomSplit({
    required String id,
    required String transactionId,
    required Map<String, double> amounts,
    String? groupId,
  }) {
    if (amounts.isEmpty) {
      throw ArgumentError('Split details required');
    }
    return BillSplitModel(
      id: id,
      transactionId: transactionId,
      splitType: SplitType.custom,
      splitDetails: amounts,
      groupId: groupId,
    );
  }

  String formatSplitDescription(
    BillSplitModel split,
    Map<String, ContactModel> contactsById,
  ) {
    final parts = split.splitDetails.entries.map((e) {
      final name = contactsById[e.key]?.name ?? e.key;
      return '$name: ${e.value.toStringAsFixed(0)}';
    });
    return '[split: ${parts.join(', ')}]';
  }
}
