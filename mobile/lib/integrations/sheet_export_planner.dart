import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/split_service.dart';
import 'package:spendwise_mobile/integrations/google_sync.dart';
import 'package:spendwise_mobile/integrations/sheet_sync_registry.dart';

class SheetExportPlanner {
  Future<List<PendingSheetRow>> buildPendingRows({
    required AppDatabase db,
    required SheetSyncRegistry registry,
    required Map<String, PaymentSourceModel> sources,
    required Map<String, ContactModel> contacts,
    required Map<String, PaymentMethodModel> methods,
    required Map<String, PaymentAppModel> apps,
    required Map<String, GroupModel> groups,
    required int metadataStartColumnIndex,
  }) async {
    final txns = await db.getTransactions();
    final settlements = await db.getAllSplitSettlements();
    final settlementByIncomeId = {
      for (final s in settlements) s.incomeTransactionId: s,
    };
    final splitsByTxn = await db.getBillSplitsByTransactionId();

    final rows = <PendingSheetRow>[];

    for (final txn in txns) {
      final plan = registry.plan(txn);
      if (plan.action == SheetSyncAction.skip) continue;

      final source = sources[txn.paymentSourceId];
      if (source == null) continue;

      rows.add(
        await _buildRow(
          db: db,
          txn: txn,
          source: source,
          plan: plan,
          contacts: contacts,
          methods: methods,
          apps: apps,
          groups: groups,
          splitsByTxn: splitsByTxn,
          settlementByIncomeId: settlementByIncomeId,
          metadataStartColumnIndex: metadataStartColumnIndex,
        ),
      );

      if (txn.cashbackFromExpenseId != null) continue;

      for (final cb in await db.getCashbacksForTransaction(txn.id)) {
        if (cb.incomeTransactionId == null) continue;
        final inc = await db.getTransaction(cb.incomeTransactionId!);
        if (inc == null) continue;
        final creditSource = sources[inc.paymentSourceId];
        if (creditSource == null) continue;

        final cbPlan = registry.plan(inc);
        if (cbPlan.action == SheetSyncAction.skip) continue;

        rows.add(
          await _buildRow(
            db: db,
            txn: inc,
            source: creditSource,
            plan: cbPlan,
            contacts: contacts,
            methods: methods,
            apps: apps,
            groups: groups,
            splitsByTxn: splitsByTxn,
            settlementByIncomeId: settlementByIncomeId,
            descriptionSuffix: ' [cashback]',
            parentTransactionId: txn.id,
            metadataStartColumnIndex: metadataStartColumnIndex,
          ),
        );
      }
    }

    return rows;
  }

  Future<PendingSheetRow> _buildRow({
    required AppDatabase db,
    required TransactionModel txn,
    required PaymentSourceModel source,
    required PlannedSheetSync plan,
    required Map<String, ContactModel> contacts,
    required Map<String, PaymentMethodModel> methods,
    required Map<String, PaymentAppModel> apps,
    required Map<String, GroupModel> groups,
    required Map<String, BillSplitModel> splitsByTxn,
    required Map<String, SplitSettlementModel> settlementByIncomeId,
    String descriptionSuffix = '',
    String? parentTransactionId,
    required int metadataStartColumnIndex,
  }) async {
    final split = splitsByTxn[txn.id];
    var suffix = descriptionSuffix;
    if (suffix.isEmpty && split != null) {
      suffix = SplitService().formatSplitDescription(
        split,
        contacts,
        totalAmount: txn.amount,
      );
    }

    GroupModel? group;
    if (split?.groupId != null) {
      group = groups[split!.groupId!];
    }

    String? settlementContactId;
    String? settlementContactName;
    final settlement = settlementByIncomeId[txn.id];
    if (settlement != null) {
      settlementContactId = settlement.contactId;
      settlementContactName = contacts[settlement.contactId]?.name;
      final splitForExpense = splitsByTxn.values
          .where((s) => s.id == settlement.billSplitId)
          .firstOrNull;
      parentTransactionId ??= splitForExpense?.transactionId;
    }

    parentTransactionId ??= txn.cashbackFromExpenseId;

    return PendingSheetRow(
      txn: txn,
      source: source,
      descriptionSuffix: suffix,
      method: txn.paymentMethodId != null ? methods[txn.paymentMethodId!] : null,
      app: txn.paymentAppId != null ? apps[txn.paymentAppId!] : null,
      split: split,
      group: group,
      contactsById: contacts,
      parentTransactionId: parentTransactionId,
      settlementContactId: settlementContactId,
      settlementContactName: settlementContactName,
      action: plan.action,
      sheetRowNumber: plan.sheetRowNumber,
      previousAmountColumn: plan.previousEntry?.amountColumn,
      metadataStartColumnIndex: metadataStartColumnIndex,
    );
  }
}
