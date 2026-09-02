import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/balance_service.dart';
import 'package:spendwise_mobile/integrations/google_sync.dart';
import 'package:spendwise_mobile/integrations/sheet_parser.dart';

class SheetImportService {
  SheetImportService({
    required this.auth,
    required this.sheets,
    required this.db,
  });

  final GoogleAuthService auth;
  final SheetsSyncService sheets;
  final AppDatabase db;

  Future<SheetImportResult> importFromGoogleSheet({
    required String spreadsheetId,
    required String sheetGid,
    required String fallbackSheetName,
    bool replaceExisting = true,
  }) async {
    try {
      final account = await auth.signInSilently() ?? await auth.signIn();
      if (account == null) {
        return const SheetImportResult(
          success: false,
          message: 'Google sign-in required to import from sheet.',
        );
      }

      final sheetTitle = await sheets.resolveSheetTitle(
            spreadsheetId: spreadsheetId,
            gid: sheetGid,
          ) ??
          fallbackSheetName;

      final rows = await sheets.readValues(
        spreadsheetId: spreadsheetId,
        range: '$sheetTitle!A3:AS',
      );

      if (rows.isEmpty) {
        return const SheetImportResult(
          success: false,
          message: 'No data rows found in the sheet.',
        );
      }

      final parsed = SheetParser.parseAllRows(rows);
      if (parsed.isEmpty) {
        return const SheetImportResult(
          success: false,
          message: 'No transactions could be parsed from the sheet.',
        );
      }

      if (replaceExisting) {
        await db.clearAllTransactions();
        await db.resetAllSourceBalances();
      }

      final sources = await db.getPaymentSources(all: true);
      final unmatched = <String>{};
      var imported = 0;
      var skipped = 0;
      final importedIds = <String>[];

      for (final entry in parsed) {
        if (!replaceExisting && await db.transactionExists(entry.importId)) {
          skipped++;
          importedIds.add(entry.importId);
          continue;
        }

        final source = SheetParser.matchSource(
          entry.sourceNamePattern,
          sources,
        );
        if (source == null) {
          unmatched.add(entry.sourceNamePattern);
          skipped++;
          continue;
        }

        final category = SheetParser.inferCategory(entry);
        final methodId = entry.type == TransactionType.expense
            ? SheetParser.defaultMethodIdForSource(source)
            : null;

        await db.insertTransaction(
          TransactionModel(
            id: entry.importId,
            type: entry.type,
            amount: entry.amount,
            category: category,
            description: entry.description,
            timestamp: entry.date,
            paymentSourceId: source.id,
            paymentMethodId: methodId,
            notes: 'Imported from sheet row ${entry.sheetRowNumber}',
            isAutomated: true,
            updatedAt: entry.date,
          ),
        );

        imported++;
        importedIds.add(entry.importId);
      }

      await _recalculateBalancesFromTransactions();

      final state = await db.getSyncState();
      await db.saveSyncState(
        state.copyWith(
          exportedTransactionIds: [
            ...state.exportedTransactionIds,
            ...importedIds,
          ].toSet().toList(),
        ),
      );

      var message =
          'Imported $imported transaction(s) from Google Sheet (${parsed.length} parsed, $skipped skipped).';
      if (unmatched.isNotEmpty) {
        message +=
            '\nNo matching account for: ${unmatched.join(', ')}. Add them under Accounts.';
      }

      return SheetImportResult(
        success: imported > 0,
        message: message,
        imported: imported,
        skipped: skipped,
        unmatchedSources: unmatched,
      );
    } catch (e) {
      return SheetImportResult(
        success: false,
        message: 'Import failed: $e',
      );
    }
  }

  Future<void> _recalculateBalancesFromTransactions() async {
    final sources = {
      for (final s in await db.getPaymentSources(all: true)) s.id: s.copyWith(balance: 0),
    };
    final balanceService = BalanceService();

    final txns = await db.getTransactions();
    txns.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final txn in txns) {
      final source = sources[txn.paymentSourceId];
      if (source == null) continue;

      final amount = txn.type == TransactionType.expense
          ? txn.netExpenseAmount
          : txn.amount;

      balanceService.applyDelta(
        source: source,
        amount: amount,
        type: txn.type,
        sourcesById: sources,
      );
    }

    for (final source in sources.values) {
      await db.updateSourceBalance(source.id, source.balance);
    }
  }
}
