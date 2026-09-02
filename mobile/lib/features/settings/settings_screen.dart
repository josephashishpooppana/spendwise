import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/integrations/google_sync.dart';
import 'package:spendwise_mobile/integrations/sync_scheduler.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;
  String? _message;

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

  Future<void> _signIn() async {
    final auth = ref.read(googleAuthProvider);
    await auth.signIn();
    ref.invalidate(syncStateProvider);
    setState(() {});
  }

  Future<void> _signOut() async {
    await ref.read(googleAuthProvider).signOut();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final syncStateAsync = ref.watch(syncStateProvider);
    final auth = ref.watch(googleAuthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Google sync', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(auth.currentUser?.email ?? 'Not signed in'),
            subtitle: const Text('Used for Drive backup and Sheets update'),
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
            onPressed: () => SyncScheduler.registerDailySync(),
            icon: const Icon(Icons.schedule),
            label: const Text('Enable daily background sync'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
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
