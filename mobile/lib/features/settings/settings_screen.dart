import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/google_sign_in_debug.dart';
import 'package:spendwise_mobile/integrations/sheet_export_planner.dart';
import 'package:spendwise_mobile/integrations/sheet_row_builder.dart';
import 'package:spendwise_mobile/integrations/sync_scheduler.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;
  bool _importing = false;
  String? _message;

  Future<void> _importFromSheet() async {
    final db = await ref.read(databaseProvider.future);
    final count = await db.countTransactions();

    if (!mounted) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import from Google Sheet?'),
        content: Text(
          count > 0
              ? 'This will read rows from your Daily Expenses sheet (Sheet1) '
                  'and replace $count local transaction(s).\n\n'
                  'Account balances and credit card bill totals will be taken '
                  'from the last row in the sheet.\n\n'
                  'Only rows with a description in column C are imported.'
              : 'This will read existing rows from your Daily Expenses sheet '
                  '(Sheet1) into the app.\n\n'
                  'Account balances and card bill totals will be read from the '
                  'last sheet row.\n\n'
                  'Only rows with a description in column C are imported.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(count > 0 ? 'Replace & import' : 'Import'),
          ),
        ],
      ),
    );

    if (replace != true || !mounted) return;

    setState(() {
      _importing = true;
      _message = null;
    });

    try {
      final importService = await ref.read(sheetImportServiceProvider.future);
      final state = await db.getSyncState();
      final result = await importService.importFromGoogleSheet(
        spreadsheetId: state.sheetId,
        sheetGid: state.sheetGid,
        fallbackSheetName: state.sheetName,
        replaceExisting: true,
      );

      ref.invalidate(transactionsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(paymentSourcesProvider);
      ref.invalidate(syncStateProvider);
      ref.invalidate(sheetSyncRegistryProvider);

      setState(() => _message = result.message);
    } catch (e) {
      setState(() => _message = 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _message = null;
    });

    final db = await ref.read(databaseProvider.future);
    final syncService = ref.read(syncServiceProvider);
    final registry = await ref.read(sheetSyncRegistryProvider.future);
    var syncState = await db.getSyncState();
    String? provisionNote;

    try {
      final provisioner = await ref.read(sheetColumnProvisionerProvider.future);
      syncState = await provisioner.ensureAllSources(syncState: syncState);
      ref.invalidate(paymentSourcesProvider);
      ref.invalidate(syncStateProvider);
    } catch (e) {
      provisionNote = 'Sheet columns: $e';
    }

    final sources = {
      for (final s in await db.getPaymentSources(all: true)) s.id: s,
    };

    for (final id in syncState.exportedTransactionIds) {
      if (registry.entryFor(id) != null) continue;
      final txn = await db.getTransaction(id);
      if (txn == null) continue;
      final source = sources[txn.paymentSourceId];
      registry.markSynced(
        transactionId: id,
        sheetRowNumber: 0,
        syncedUpdatedAt: txn.updatedAt ?? txn.timestamp,
        paymentSourceId: txn.paymentSourceId,
        type: txn.type,
        amountColumn: source != null
            ? SheetRowBuilder.amountColumnFor(
                transaction: txn,
                source: source,
              )
            : '',
      );
    }
    await registry.save();

    final planner = SheetExportPlanner();
    final result = await syncService.syncAll(
      exportJson: db.exportAllJson,
      spreadsheetId: syncState.sheetId,
      sheetGid: syncState.sheetGid,
      fallbackSheetName: syncState.sheetName,
      driveFolderId: syncState.driveFolderId,
      metadataStartColumnIndex: syncState.metadataStartColumnIndex,
      registry: registry,
      pendingRows: () async {
        final freshState = await db.getSyncState();
        final sources = {
          for (final s in await db.getPaymentSources(all: true)) s.id: s,
        };
        final contacts = {
          for (final c in await db.getContacts()) c.id: c,
        };
        final methods = {
          for (final m in await db.getPaymentMethods()) m.id: m,
        };
        final apps = {
          for (final a in await db.getPaymentApps(all: true)) a.id: a,
        };
        final groups = {
          for (final g in await db.getGroups()) g.id: g,
        };
        return planner.buildPendingRows(
          db: db,
          registry: registry,
          sources: sources,
          contacts: contacts,
          methods: methods,
          apps: apps,
          groups: groups,
          metadataStartColumnIndex: freshState.metadataStartColumnIndex,
        );
      },
    );

    if (result.success) {
      await db.saveSyncState(
        syncState.copyWith(
          lastSyncedAt: DateTime.now(),
          driveFolderId: result.driveFolderId,
          googleAccountEmail: result.googleEmail,
        ),
      );
      ref.invalidate(syncStateProvider);
      ref.invalidate(sheetSyncRegistryProvider);
    }

    setState(() {
      _syncing = false;
      _message = provisionNote != null
          ? '${result.message}\n$provisionNote'
          : result.message;
    });
  }

  Future<void> _showOAuthDebugInfo() async {
    final report = await GoogleSignInDebugReport.buildConfigReport();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OAuth debug info'),
        content: SingleChildScrollView(
          child: SelectableText(
            report,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() => _message = null);
    try {
      final auth = ref.read(googleAuthProvider);
      final account = await auth.signIn();
      if (account == null) {
        setState(() => _message = 'Sign-in cancelled.');
        return;
      }
      final db = await ref.read(databaseProvider.future);
      final state = await db.getSyncState();
      await db.saveSyncState(
        state.copyWith(googleAccountEmail: account.email),
      );
      ref.invalidate(syncStateProvider);
      setState(() {
        _message =
            'Signed in as ${account.email}. Google will ask permission for '
            'Sheets and Drive when you tap Sync now.';
      });
    } catch (e, st) {
      final configReport = await GoogleSignInDebugReport.buildConfigReport();
      setState(() {
        _message =
            '${GoogleSignInDebugReport.formatError(e, st)}\n\n'
            '$configReport\n\n'
            'Tap "OAuth debug info" anytime for this report.';
      });
    }
  }

  Future<void> _signOut() async {
    await ref.read(googleAuthProvider).signOut();
    final db = await ref.read(databaseProvider.future);
    final state = await db.getSyncState();
    await db.saveSyncState(
      SyncStateModel(
        lastSyncedAt: state.lastSyncedAt,
        exportedTransactionIds: state.exportedTransactionIds,
        driveFolderId: state.driveFolderId,
        sheetId: state.sheetId,
        sheetGid: state.sheetGid,
        sheetName: state.sheetName,
      ),
    );
    ref.invalidate(syncStateProvider);
    setState(() => _message = 'Signed out.');
  }

  @override
  Widget build(BuildContext context) {
    final syncStateAsync = ref.watch(syncStateProvider);
    final registryAsync = ref.watch(sheetSyncRegistryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Google sync', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Sync now pushes app changes to Google Sheet only (sheet is not edited '
            'manually). New transactions are appended; edited ones update their existing row. '
            'Import pulls history from the sheet (description required in column C).',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          syncStateAsync.when(
            loading: () => const ListTile(
              leading: Icon(Icons.account_circle),
              title: Text('Loading…'),
            ),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text('Error: $e'),
            ),
            data: (state) => ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(state.googleAccountEmail ?? 'Not signed in'),
              subtitle: const Text('Used for Drive backup and Sheets update'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _signIn,
                  child: const Text('Sign in'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _signOut,
                  child: const Text('Sign out'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          syncStateAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (state) => registryAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (registry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last sync: ${state.lastSyncedAt != null ? Formatters.dateTime.format(state.lastSyncedAt!) : 'Never'}',
                  ),
                  Text('Sheet: ${state.sheetName} (${state.sheetId.substring(0, 8)}…)'),
                  Text('Sheet sync registry: ${registry.entries.length} transaction(s)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _syncing ? null : _syncNow,
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(_syncing ? 'Syncing…' : 'Sync now'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: (_importing || _syncing) ? null : _importFromSheet,
            icon: _importing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_importing ? 'Importing…' : 'Import from Google Sheet'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showOAuthDebugInfo,
            icon: const Icon(Icons.bug_report_outlined),
            label: const Text('OAuth debug info'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await SyncScheduler.registerDailySync();
              setState(() {
                _message =
                    'Use Sync now when you open the app. Automatic background sync is not enabled on this build.';
              });
            },
            icon: const Icon(Icons.schedule),
            label: const Text('Daily sync reminder'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              _message!,
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const Divider(height: 32),
          Text('About', style: Theme.of(context).textTheme.titleLarge),
          const Text(
            'SpendWise stores all data locally on your device. '
            'New accounts automatically add Credit/Debit/Balance columns to your Google Sheet. '
            'Sync tracks each transaction in spendwise_sheet_sync.json beside the local database.',
          ),
        ],
      ),
    );
  }
}
