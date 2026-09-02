import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/balance_service.dart';
import 'package:spendwise_mobile/integrations/google_sync.dart';
import 'package:spendwise_mobile/integrations/sheet_balance_reader.dart';
import 'package:spendwise_mobile/integrations/sheet_column_provisioner.dart';
import 'package:spendwise_mobile/integrations/sheet_parser.dart';
import 'package:spendwise_mobile/integrations/sheet_range.dart';
import 'package:spendwise_mobile/integrations/sheet_sync_registry.dart';
import 'package:uuid/uuid.dart';

class SheetImportService {
  SheetImportService({
    required this.auth,
    required this.sheets,
    required this.db,
    required this.registry,
  });

  final GoogleAuthService auth;
  final SheetsSyncService sheets;
  final AppDatabase db;
  final SheetSyncRegistry registry;
  static const _uuid = Uuid();

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
      );
      final resolvedTitle =
          sheetTitle.isNotEmpty ? sheetTitle : fallbackSheetName;
      final syncState = await db.getSyncState();
      final rangeEnd = SheetColumnProvisioner.appendRangeEndColumn(
        syncState.metadataStartColumnIndex,
      );
      final fullRange = formatSheetRange(resolvedTitle, 'A1:$rangeEnd');

      final allRows = await sheets.readValues(
        spreadsheetId: spreadsheetId,
        range: fullRange,
      );

      List<Object?> headerRow = const [];
      List<Object?> subHeaderRow = const [];
      final List<List<Object?>> rows;
      if (allRows.length >= 3) {
        headerRow = allRows[0];
        subHeaderRow = allRows[1];
        rows = allRows.sublist(2);
      } else {
        rows = allRows;
      }

      if (rows.isEmpty) {
        return SheetImportResult(
          success: false,
          message: 'No data rows found in $resolvedTitle. '
              'Check that the sheet has data from row 3 and your account has access.',
        );
      }

      var sources = await db.getPaymentSources(all: true);
      final headerMappings = SheetParser.mappingsFromSheetHeaders(
        headerRow,
        subHeaderRow,
        metadataStartColumnIndex: syncState.metadataStartColumnIndex,
      );
      final createdSources = await _ensureSourcesFromHeaderMappings(
        headerMappings: headerMappings,
        sources: sources,
      );
      if (createdSources.isNotEmpty) {
        sources = await db.getPaymentSources(all: true);
      }

      final mappings = SheetParser.buildImportMappings(
        sources: sources,
        headerRow: headerRow,
        subHeaderRow: subHeaderRow,
        metadataStartColumnIndex: syncState.metadataStartColumnIndex,
      );
      final parsed = SheetParser.parseAllRows(
        rows,
        mappings: mappings,
        metadataStartColumnIndex: syncState.metadataStartColumnIndex,
      );
      if (parsed.isEmpty) {
        return SheetImportResult(
          success: false,
          message: 'Read ${rows.length} row(s) from $resolvedTitle but could not '
              'parse any transactions. Rows need a date, non-empty description (column C), '
              'and credit or debit greater than zero.',
        );
      }

      if (replaceExisting) {
        await db.clearAllTransactions();
        await db.resetAllSourceBalances();
        for (final id in registry.entries.keys.toList()) {
          registry.remove(id);
        }
      }

      final methods = await db.getPaymentMethods();
      final apps = await db.getPaymentApps(all: true);
      final unmatched = <String>{};
      var imported = 0;
      var skipped = 0;

      for (final entry in parsed) {
        if (!replaceExisting && await db.transactionExists(entry.importId)) {
          skipped++;
          _registerImported(entry);
          continue;
        }

        final source = _resolveSource(entry, sources);
        if (source == null) {
          unmatched.add(entry.sourceNamePattern);
          skipped++;
          continue;
        }

        final category = SheetParser.inferCategory(entry);
        final methodId = _resolveMethodId(entry, source, methods);
        final appId = _resolveAppId(entry, apps);
        final notes = entry.metadata.notes.isNotEmpty
            ? entry.metadata.notes
            : 'Imported from sheet row ${entry.sheetRowNumber}';

        await db.insertTransaction(
          TransactionModel(
            id: entry.importId,
            type: entry.type,
            amount: entry.metadata.grossAmount ?? entry.amount,
            category: category,
            description: entry.description,
            timestamp: entry.date,
            paymentSourceId: source.id,
            paymentMethodId: methodId,
            paymentAppId: appId,
            notes: notes,
            cashbackReceived: entry.metadata.cashback ?? 0,
            isAutomated: true,
            updatedAt: entry.date,
          ),
        );

        _registerImported(entry, source: source);
        imported++;
      }

      var balanceNote = '';
      if (replaceExisting) {
        final sourcesForBalance = await db.getPaymentSources(all: true);
        balanceNote = await _applyOpeningBalancesFromSheet(
          rows: rows,
          sources: sourcesForBalance,
        );
      } else {
        await _recalculateBalancesFromTransactions();
      }

      await registry.save();

      var message =
          'Imported $imported transaction(s) from Google Sheet (${parsed.length} parsed, $skipped skipped). '
          'Rows with empty description were ignored.';
      if (createdSources.isNotEmpty) {
        message +=
            '\nAdded ${createdSources.length} account(s) from sheet headers: ${createdSources.join(', ')}.';
      }
      if (balanceNote.isNotEmpty) {
        message += '\n$balanceNote';
      }
      if (unmatched.isNotEmpty) {
        message +=
            '\nNo matching account for: ${unmatched.join(', ')}.';
      }

      return SheetImportResult(
        success: imported > 0,
        message: message,
        imported: imported,
        skipped: skipped,
        unmatchedSources: unmatched,
        sourcesCreated: createdSources.length,
      );
    } catch (e) {
      return SheetImportResult(
        success: false,
        message: 'Import failed: $e\n\n'
            'Sign out and sign in again, allow Sheets access, and confirm '
            'your Google account can edit the spreadsheet.',
      );
    }
  }

  PaymentSourceModel? _resolveSource(
    ParsedSheetTransaction entry,
    List<PaymentSourceModel> sources,
  ) {
    if (entry.metadata.sourceId.isNotEmpty) {
      for (final s in sources) {
        if (s.id == entry.metadata.sourceId) return s;
      }
    }
    if (entry.metadata.sourceName.isNotEmpty &&
        entry.metadata.sourceName != SheetImportMetadata.unknown) {
      for (final s in sources) {
        if (s.name == entry.metadata.sourceName) return s;
      }
    }
    return SheetParser.matchSource(entry.sourceNamePattern, sources);
  }

  Future<Set<String>> _ensureSourcesFromHeaderMappings({
    required List<SheetColumnMapping> headerMappings,
    required List<PaymentSourceModel> sources,
  }) async {
    final created = <String>{};

    for (final mapping in headerMappings) {
      if (SheetParser.mappingCoveredBySource(mapping, sources)) continue;

      final source = PaymentSourceModel(
        id: _uuid.v4(),
        name: mapping.sourceNamePattern,
        sourceTypeKey: mapping.sourceTypeKey,
        sheetCreditColumn: mapping.creditColumn,
        sheetDebitColumn: mapping.debitColumn,
        sheetBalanceColumn: mapping.balanceColumn,
      );
      await db.upsertPaymentSource(source);
      sources.add(source);
      created.add(mapping.sourceNamePattern);
    }

    return created;
  }

  String? _resolveMethodId(
    ParsedSheetTransaction entry,
    PaymentSourceModel source,
    List<PaymentMethodModel> methods,
  ) {
    if (entry.metadata.methodId.isNotEmpty) {
      for (final m in methods) {
        if (m.id == entry.metadata.methodId) return m.id;
      }
    }
    if (entry.metadata.methodName.isNotEmpty &&
        entry.metadata.methodName != SheetImportMetadata.unknown) {
      for (final m in methods) {
        if (m.name == entry.metadata.methodName) return m.id;
      }
    }
    return entry.type == TransactionType.expense
        ? SheetParser.defaultMethodIdForSource(source)
        : null;
  }

  String? _resolveAppId(
    ParsedSheetTransaction entry,
    List<PaymentAppModel> apps,
  ) {
    if (entry.metadata.appId.isNotEmpty) {
      for (final a in apps) {
        if (a.id == entry.metadata.appId) return a.id;
      }
    }
    if (entry.metadata.appName.isNotEmpty &&
        entry.metadata.appName != SheetImportMetadata.unknown) {
      for (final a in apps) {
        if (a.name == entry.metadata.appName) return a.id;
      }
    }
    return null;
  }

  void _registerImported(
    ParsedSheetTransaction entry, {
    PaymentSourceModel? source,
  }) {
    registry.markSynced(
      transactionId: entry.importId,
      sheetRowNumber: entry.sheetRowNumber,
      syncedUpdatedAt: entry.date,
      paymentSourceId: source?.id ?? entry.metadata.sourceId,
      type: entry.type,
      amountColumn: entry.columnKey,
    );
  }

  Future<String> _applyOpeningBalancesFromSheet({
    required List<List<Object?>> rows,
    required List<PaymentSourceModel> sources,
  }) async {
    final balances = SheetBalanceReader.fromLastSheetRow(
      rows: rows,
      sources: sources,
    );
    if (balances.isEmpty) {
      await _recalculateBalancesFromTransactions();
      return 'Could not read balances from the last sheet row; balances computed from imported transactions.';
    }

    final rowIndex = SheetBalanceReader.findLastDataRowIndex(rows);
    final sheetRow = rowIndex != null ? 3 + rowIndex : null;

    var applied = 0;
    for (final source in sources) {
      final value = balances[source.id];
      if (value == null) continue;
      await db.updateSourceBalance(source.id, value);
      applied++;
    }

    if (applied == 0) {
      await _recalculateBalancesFromTransactions();
      return 'No account balance columns matched on the last sheet row.';
    }

    final parts = <String>[];
    for (final source in sources) {
      final value = balances[source.id];
      if (value == null) continue;
      if (source.sourceTypeKey == 'CREDIT_CARD') {
        parts.add('${source.name} bill ${value.toStringAsFixed(2)}');
      } else {
        parts.add('${source.name} ${value.toStringAsFixed(2)}');
      }
    }

    return 'Opening balances from sheet row ${sheetRow ?? '?'}: ${parts.join(', ')}.';
  }

  Future<void> _recalculateBalancesFromTransactions() async {
    final sources = {
      for (final s in await db.getPaymentSources(all: true))
        s.id: s.copyWith(balance: 0),
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
