import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/google_sign_in_debug.dart';
import 'package:spendwise_mobile/integrations/google_sync.dart';
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
              ? 'This will read all rows from your Daily Expenses sheet (Sheet1) '
                  'and replace $count local transaction(s).\n\n'
                  'Sign in with Google first if you have not already.'
              : 'This will read all existing rows from your Daily Expenses sheet '
                  '(Sheet1) into the app.',
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
    final state = await db.getSyncState();
    final sources = {
      for (final s in await db.getPaymentSources(all: true)) s.id: s,
    };
    final contacts = {
      for (final c in await db.getContacts()) c.id: c,
    };

    final result = await syncService.syncAll(
      exportJson: db.exportAllJson,
      spreadsheetId: state.sheetId,
      sheetGid: state.sheetGid,
      fallbackSheetName: state.sheetName,
      driveFolderId: state.driveFolderId,
      pendingRows: () async {
        final unsynced = await db.getUnsyncedTransactions(state);
        final rows = <PendingSheetRow>[];
        for (final txn in unsynced) {
          final source = sources[txn.paymentSourceId];
          if (source == null) continue;
          var suffix = '';
          final split = await db.getBillSplitForTransaction(txn.id);
          if (split != null) {
            final parts = split.splitDetails.entries.map((e) {
              final name = contacts[e.key]?.name ?? e.key;
              return '$name:${e.value.toStringAsFixed(0)}';
            });
            suffix = ' [split: ${parts.join(', ')}]';
          }
          rows.add(PendingSheetRow(txn: txn, source: source, suffix: suffix));

          if (txn.cashbackFromExpenseId != null) {
            continue;
          }
          for (final cb in await db.getCashbacksForTransaction(txn.id)) {
            if (cb.incomeTransactionId != null) {
              final inc = await db.getTransaction(cb.incomeTransactionId!);
              final creditSource = inc != null
                  ? sources[inc.paymentSourceId]
                  : null;
              if (inc != null && creditSource != null) {
                rows.add(
                  PendingSheetRow(
                    txn: inc,
                    source: creditSource,
                    suffix: ' [cashback]',
                  ),
                );
              }
            }
          }
        }
        return rows;
      },
    );

    if (result.success) {
      final exportedIds = [
        ...state.exportedTransactionIds,
        ...(await db.getUnsyncedTransactions(state)).map((t) => t.id),
      ];
      await db.saveSyncState(
        state.copyWith(
          lastSyncedAt: DateTime.now(),
          exportedTransactionIds: exportedIds.toSet().toList(),
          driveFolderId: result.driveFolderId,
          googleAccountEmail: result.googleEmail,
        ),
      );
      ref.invalidate(syncStateProvider);
    }

    setState(() {
      _syncing = false;
      _message = result.message;
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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Google sync', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Google sign-in is optional and not shown at app launch. '
            'Tap Sign in here, then Sync now. Google will request access to '
            'update your spreadsheet and save backups to Drive.',
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
            data: (state) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last sync: ${state.lastSyncedAt != null ? Formatters.dateTime.format(state.lastSyncedAt!) : 'Never'}'),
                Text('Sheet: ${state.sheetName} (${state.sheetId.substring(0, 8)}…)'),
                Text('Exported transactions: ${state.exportedTransactionIds.length}'),
              ],
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
            'Daily sync uploads a JSON backup to Google Drive and appends new transactions to your Google Sheet.',
          ),
        ],
      ),
    );
  }
}
