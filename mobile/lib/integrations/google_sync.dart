import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as gsheets;
import 'package:spendwise_mobile/integrations/sheet_sync_registry.dart';
import 'package:http/http.dart' as http;
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/core/google_config.dart';
import 'package:spendwise_mobile/integrations/drive_backup_naming.dart';
import 'package:spendwise_mobile/integrations/sheet_row_locator.dart';
import 'package:spendwise_mobile/integrations/sheet_range.dart';
import 'package:spendwise_mobile/integrations/sheet_row_builder.dart';
import 'package:spendwise_mobile/integrations/sheet_row_inserter.dart';
import 'package:spendwise_mobile/integrations/sheet_column_provisioner.dart';

const _scopes = [
  gsheets.SheetsApi.spreadsheetsScope,
  drive.DriveApi.driveFileScope,
];

class PendingSheetRow {
  const PendingSheetRow({
    required this.txn,
    required this.source,
    this.descriptionSuffix = '',
    this.method,
    this.app,
    this.split,
    this.group,
    this.contactsById = const {},
    this.parentTransactionId,
    this.settlementContactId,
    this.settlementContactName,
    this.action = SheetSyncAction.append,
    this.sheetRowNumber,
    this.previousAmountColumn,
    this.metadataStartColumnIndex = 26,
  });

  final TransactionModel txn;
  final PaymentSourceModel source;
  final String descriptionSuffix;
  final PaymentMethodModel? method;
  final PaymentAppModel? app;
  final BillSplitModel? split;
  final GroupModel? group;
  final Map<String, ContactModel> contactsById;
  final String? parentTransactionId;
  final String? settlementContactId;
  final String? settlementContactName;
  final SheetSyncAction action;
  final int? sheetRowNumber;
  final String? previousAmountColumn;
  final int metadataStartColumnIndex;

  List<Object?> buildSheetRow() => SheetRowBuilder.buildRow(
        transaction: txn,
        source: source,
        metadataStartColumnIndex: metadataStartColumnIndex,
        descriptionSuffix: descriptionSuffix,
        method: method,
        app: app,
        split: split,
        group: group,
        contactsById: contactsById,
        parentTransactionId: parentTransactionId,
        settlementContactId: settlementContactId,
        settlementContactName: settlementContactName,
      );

  String get amountColumn => SheetRowBuilder.amountColumnFor(
        transaction: txn,
        source: source,
      );
}

/// Google Sign-In is created lazily so native code is not touched at app launch.
class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? signIn}) : _signInOverride = signIn;

  final GoogleSignIn? _signInOverride;
  GoogleSignIn? _signIn;

  GoogleSignIn get _client => _signInOverride ??
      (_signIn ??= GoogleSignIn(
        scopes: _scopes,
        serverClientId:
            GoogleConfig.webClientId.isEmpty ? null : GoogleConfig.webClientId,
      ));

  GoogleSignInAccount? get currentUser {
    try {
      return _client.currentUser;
    } catch (e) {
      debugPrint('GoogleSignIn currentUser failed: $e');
      return null;
    }
  }

  Future<GoogleSignInAccount?> signIn() => _client.signIn();

  Future<void> signOut() => _client.signOut();

  Future<GoogleSignInAccount?> signInSilently() => _client.signInSilently();

  Future<http.Client> requireAuthClient() async {
    final granted = await _client.requestScopes(_scopes);
    if (!granted) {
      throw StateError(
        'Google Sheets/Drive permission was denied. '
        'Sign out, sign in again, and allow all requested permissions.',
      );
    }

    final client = await _client.authenticatedClient();
    if (client == null) {
      throw StateError(
        'Could not connect to Google APIs. Sign out and sign in again.',
      );
    }
    return client;
  }

  Future<gsheets.SheetsApi> getSheetsApi() async {
    final client = await requireAuthClient();
    return gsheets.SheetsApi(client);
  }

  Future<drive.DriveApi> getDriveApi() async {
    final client = await requireAuthClient();
    return drive.DriveApi(client);
  }
}

class DriveSyncService {
  DriveSyncService(this._auth);

  final GoogleAuthService _auth;

  Future<String?> uploadWeeklyBackup({
    required String jsonContent,
    String? folderId,
    DateTime? now,
  }) async {
    final api = await _auth.getDriveApi();
    final fileName = DriveBackupNaming.weeklyFileName(now);
    final bytes = utf8.encode(jsonContent);
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    if (folderId != null) {
      final escaped = fileName.replaceAll("'", r"\'");
      final query =
          "name='$escaped' and '$folderId' in parents and trashed=false";
      final existing = await api.files.list(
        q: query,
        spaces: 'drive',
      );
      for (final f in existing.files ?? []) {
        if (f.id != null) {
          await api.files.delete(f.id!);
        }
      }
    }

    final file = drive.File()
      ..name = fileName
      ..parents = folderId != null ? [folderId] : null;

    final created = await api.files.create(
      file,
      uploadMedia: media,
    );
    return created.id;
  }

  Future<String?> ensureBackupFolder() async {
    final api = await _auth.getDriveApi();
    const folderName = 'SpendWise Backups';
    const query =
        "mimeType='application/vnd.google-apps.folder' and name='SpendWise Backups' and trashed=false";
    final existing = await api.files.list(q: query, spaces: 'drive');
    if (existing.files != null && existing.files!.isNotEmpty) {
      return existing.files!.first.id;
    }

    final folder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    return created.id;
  }
}

class SheetsSyncService {
  SheetsSyncService(this._auth);

  final GoogleAuthService _auth;

  Future<String> resolveSheetTitle({
    required String spreadsheetId,
    required String gid,
  }) async {
    final api = await _auth.getSheetsApi();

    final spreadsheet = await api.spreadsheets.get(spreadsheetId);
    for (final sheet in spreadsheet.sheets ?? []) {
      if ('${sheet.properties?.sheetId}' == gid) {
        return sheet.properties?.title ?? '';
      }
    }
    return spreadsheet.sheets?.first.properties?.title ?? '';
  }

  Future<List<List<Object?>>> readValues({
    required String spreadsheetId,
    required String range,
  }) async {
    final api = await _auth.getSheetsApi();

    final response = await api.spreadsheets.values.get(
      spreadsheetId,
      range,
      valueRenderOption: 'UNFORMATTED_VALUE',
    );
    final values = response.values;
    if (values == null) return [];

    return values
        .map((row) => row.map<Object?>((cell) => cell).toList())
        .toList();
  }

  /// Reads large sheets in row chunks to avoid mobile network timeouts.
  Future<List<List<Object?>>> readValuesInRowChunks({
    required String spreadsheetId,
    required String sheetTitle,
    required String rangeEndColumn,
    int startRow = 1,
    int chunkSize = 500,
  }) async {
    final allRows = <List<Object?>>[];
    var rowStart = startRow;

    while (true) {
      final rowEnd = rowStart + chunkSize - 1;
      final range = formatSheetRange(
        sheetTitle,
        'A$rowStart:$rangeEndColumn$rowEnd',
      );
      final chunk = await readValues(
        spreadsheetId: spreadsheetId,
        range: range,
      );
      if (chunk.isEmpty) break;

      allRows.addAll(chunk);
      if (chunk.length < chunkSize) break;
      rowStart += chunkSize;
    }

    return allRows;
  }

  Future<int> resolveSheetId({
    required String spreadsheetId,
    required String gid,
  }) async {
    final api = await _auth.getSheetsApi();
    final spreadsheet = await api.spreadsheets.get(spreadsheetId);
    for (final sheet in spreadsheet.sheets ?? []) {
      if ('${sheet.properties?.sheetId}' == gid) {
        final id = sheet.properties?.sheetId;
        if (id == null) throw StateError('Sheet id missing for gid $gid');
        return id;
      }
    }
    throw StateError('Sheet tab not found (gid $gid)');
  }

  Future<void> insertColumns({
    required String spreadsheetId,
    required int sheetId,
    required int startIndex,
    required int columnCount,
  }) async {
    if (columnCount <= 0) return;
    final api = await _auth.getSheetsApi();
    await api.spreadsheets.batchUpdate(
      gsheets.BatchUpdateSpreadsheetRequest(
        requests: [
          gsheets.Request(
            insertDimension: gsheets.InsertDimensionRequest(
              range: gsheets.DimensionRange(
                sheetId: sheetId,
                dimension: 'COLUMNS',
                startIndex: startIndex,
                endIndex: startIndex + columnCount,
              ),
              inheritFromBefore: true,
            ),
          ),
        ],
      ),
      spreadsheetId,
    );
  }

  Future<int?> appendRows({
    required String spreadsheetId,
    required String sheetTitle,
    required List<List<Object?>> rows,
    required String rangeEndColumn,
  }) async {
    if (rows.isEmpty) return null;

    final api = await _auth.getSheetsApi();
    final range = formatSheetRange(sheetTitle, 'A:$rangeEndColumn');
    final request = gsheets.ValueRange(values: rows);
    final response = await api.spreadsheets.values.append(
      request,
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );
    return SheetRowBuilder.parseStartRowFromUpdatedRange(
      response.updates?.updatedRange,
    );
  }

  Future<void> batchUpdateRanges({
    required String spreadsheetId,
    required List<gsheets.ValueRange> ranges,
  }) async {
    if (ranges.isEmpty) return;
    final api = await _auth.getSheetsApi();
    await api.spreadsheets.values.batchUpdate(
      gsheets.BatchUpdateValuesRequest(
        valueInputOption: 'USER_ENTERED',
        data: ranges,
      ),
      spreadsheetId,
    );
  }

  Future<void> insertRowsAt({
    required String spreadsheetId,
    required int sheetId,
    required int sheetRowNumber,
    int rowCount = 1,
  }) async {
    if (rowCount <= 0) return;
    final api = await _auth.getSheetsApi();
    await api.spreadsheets.batchUpdate(
      gsheets.BatchUpdateSpreadsheetRequest(
        requests: [
          gsheets.Request(
            insertDimension: gsheets.InsertDimensionRequest(
              range: gsheets.DimensionRange(
                sheetId: sheetId,
                dimension: 'ROWS',
                startIndex: sheetRowNumber - 1,
                endIndex: sheetRowNumber - 1 + rowCount,
              ),
              inheritFromBefore: true,
            ),
          ),
        ],
      ),
      spreadsheetId,
    );
  }

  Future<void> deleteRows({
    required String spreadsheetId,
    required int sheetId,
    required List<int> sheetRowNumbers,
  }) async {
    if (sheetRowNumbers.isEmpty) return;
    final api = await _auth.getSheetsApi();
    final sorted = sheetRowNumbers.toList()..sort((a, b) => b.compareTo(a));
    final requests = sorted
        .map(
          (rowNum) => gsheets.Request(
            deleteDimension: gsheets.DeleteDimensionRequest(
              range: gsheets.DimensionRange(
                sheetId: sheetId,
                dimension: 'ROWS',
                startIndex: rowNum - 1,
                endIndex: rowNum,
              ),
            ),
          ),
        )
        .toList();
    await api.spreadsheets.batchUpdate(
      gsheets.BatchUpdateSpreadsheetRequest(requests: requests),
      spreadsheetId,
    );
  }

  Future<void> writeRowAt({
    required String spreadsheetId,
    required String sheetTitle,
    required int rowNumber,
    required List<Object?> row,
    required String rangeEndColumn,
  }) async {
    final range =
        formatSheetRange(sheetTitle, 'A$rowNumber:$rangeEndColumn$rowNumber');
    await batchUpdateRanges(
      spreadsheetId: spreadsheetId,
      ranges: [gsheets.ValueRange(range: range, values: [row])],
    );
  }
}

class SyncResult {
  const SyncResult({
    required this.success,
    required this.message,
    this.appendedCount = 0,
    this.updatedCount = 0,
    this.deletedCount = 0,
    this.movedCount = 0,
    this.skippedCount = 0,
    this.driveFolderId,
    this.googleEmail,
  });

  final bool success;
  final String message;
  final int appendedCount;
  final int updatedCount;
  final int deletedCount;
  final int movedCount;
  final int skippedCount;
  final String? driveFolderId;
  final String? googleEmail;
}

class _PlannedInsert {
  const _PlannedInsert({
    required this.row,
    required this.targetRow,
  });

  final PendingSheetRow row;
  final int targetRow;
}

class SyncService {
  SyncService({
    required this.auth,
    required this.drive,
    required this.sheets,
  });

  final GoogleAuthService auth;
  final DriveSyncService drive;
  final SheetsSyncService sheets;

  Future<SyncResult> syncAll({
    required Future<String> Function() exportJson,
    required Future<List<PendingSheetRow>> Function() pendingRows,
    required SheetSyncRegistry registry,
    required String spreadsheetId,
    required String sheetGid,
    required String fallbackSheetName,
    required int metadataStartColumnIndex,
    String? driveFolderId,
  }) async {
    try {
      final account = await auth.signInSilently() ?? await auth.signIn();
      if (account == null) {
        return const SyncResult(success: false, message: 'Google sign-in cancelled');
      }

      String? folderId = driveFolderId;
      String? backupNote;
      try {
        folderId ??= await drive.ensureBackupFolder();
        final json = await exportJson();
        final backupFileName = DriveBackupNaming.weeklyFileName();
        await drive.uploadWeeklyBackup(
          jsonContent: json,
          folderId: folderId,
        );
        backupNote = 'Drive backup saved ($backupFileName).';
      } catch (e) {
        debugPrint('Drive backup skipped: $e');
        backupNote = 'Drive backup skipped: $e';
      }

      var sheetTitle = await sheets.resolveSheetTitle(
        spreadsheetId: spreadsheetId,
        gid: sheetGid,
      );
      if (sheetTitle.isEmpty) {
        sheetTitle = fallbackSheetName;
      }

      final pending = await pendingRows();
      final toAppend =
          pending.where((p) => p.action == SheetSyncAction.append).toList();
      final toUpdate =
          pending.where((p) => p.action == SheetSyncAction.update).toList();

      final rangeEnd =
          SheetColumnProvisioner.appendRangeEndColumn(metadataStartColumnIndex);

      final sheetId = await sheets.resolveSheetId(
        spreadsheetId: spreadsheetId,
        gid: sheetGid,
      );

      var deleted = 0;
      var appended = 0;
      var updated = 0;
      var moved = 0;
      var usedAppendFallback = false;

      final pendingDeletes = registry.pendingDeletes.toList()
        ..sort((a, b) => b.sheetRowNumber.compareTo(a.sheetRowNumber));
      if (pendingDeletes.isNotEmpty) {
        await sheets.deleteRows(
          spreadsheetId: spreadsheetId,
          sheetId: sheetId,
          sheetRowNumbers: pendingDeletes.map((d) => d.sheetRowNumber).toList(),
        );
        for (final del in pendingDeletes) {
          registry.shiftRowNumbers(del.sheetRowNumber + 1, -1);
        }
        deleted = pendingDeletes.length;
        registry.clearPendingDeletes();
      }

      List<List<Object?>>? sheetSnapshot;
      Future<List<List<Object?>>> loadSheetSnapshot() async {
        sheetSnapshot ??= await sheets.readValues(
          spreadsheetId: spreadsheetId,
          range: formatSheetRange(sheetTitle, 'A3:$rangeEnd'),
        );
        return sheetSnapshot!;
      }

      if (toAppend.isNotEmpty) {
        try {
          final snapshot = (await loadSheetSnapshot())
              .map((r) => List<Object?>.from(r))
              .toList();
          final parentTargets = <String, int>{};
          final planned = <_PlannedInsert>[];

          for (final p in toAppend) {
            int target;
            if (p.parentTransactionId != null &&
                parentTargets.containsKey(p.parentTransactionId)) {
              target = parentTargets[p.parentTransactionId]! + 1;
            } else {
              target = SheetRowInserter.targetInsertRow(
                txnDate: p.txn.timestamp,
                sheetRows: snapshot,
              );
            }
            planned.add(_PlannedInsert(row: p, targetRow: target));
            parentTargets[p.txn.id] = target;
            SheetRowInserter.insertPlaceholderRowAt(snapshot, target);
          }

          planned.sort((a, b) => b.targetRow.compareTo(a.targetRow));

          for (final plan in planned) {
            await sheets.insertRowsAt(
              spreadsheetId: spreadsheetId,
              sheetId: sheetId,
              sheetRowNumber: plan.targetRow,
            );
            registry.shiftRowNumbers(plan.targetRow, 1);
            await sheets.writeRowAt(
              spreadsheetId: spreadsheetId,
              sheetTitle: sheetTitle,
              rowNumber: plan.targetRow,
              row: plan.row.buildSheetRow(),
              rangeEndColumn: rangeEnd,
            );
            registry.markSynced(
              transactionId: plan.row.txn.id,
              sheetRowNumber: plan.targetRow,
              syncedUpdatedAt:
                  plan.row.txn.updatedAt ?? plan.row.txn.timestamp,
              paymentSourceId: plan.row.source.id,
              type: plan.row.txn.type,
              amountColumn: plan.row.amountColumn,
            );
            appended++;
          }
          sheetSnapshot = null;
        } catch (e) {
          debugPrint('Chronological insert failed, falling back to append: $e');
          usedAppendFallback = true;
          final appendRows = toAppend.map((p) => p.buildSheetRow()).toList();
          final startRow = await sheets.appendRows(
            spreadsheetId: spreadsheetId,
            sheetTitle: sheetTitle,
            rows: appendRows,
            rangeEndColumn: rangeEnd,
          );
          if (startRow != null) {
            for (var i = 0; i < toAppend.length; i++) {
              final p = toAppend[i];
              registry.markSynced(
                transactionId: p.txn.id,
                sheetRowNumber: startRow + i,
                syncedUpdatedAt: p.txn.updatedAt ?? p.txn.timestamp,
                paymentSourceId: p.source.id,
                type: p.txn.type,
                amountColumn: p.amountColumn,
              );
            }
            appended = toAppend.length;
          }
        }
      }

      final updateRanges = <gsheets.ValueRange>[];
      for (final p in toUpdate) {
        var rowNumber = p.sheetRowNumber;
        if (rowNumber == null || rowNumber <= 0) {
          final snapshot = await loadSheetSnapshot();
          rowNumber = SheetRowLocator.findRow(
            txn: p.txn,
            source: p.source,
            sheetRows: snapshot,
            metadataStartColumnIndex: metadataStartColumnIndex,
          );
          if (rowNumber == null) {
            debugPrint(
              'Could not locate sheet row for ${p.txn.id}; inserting instead.',
            );
            try {
              final snapshot = (await loadSheetSnapshot())
                  .map((r) => List<Object?>.from(r))
                  .toList();
              final target = SheetRowInserter.targetInsertRow(
                txnDate: p.txn.timestamp,
                sheetRows: snapshot,
              );
              await sheets.insertRowsAt(
                spreadsheetId: spreadsheetId,
                sheetId: sheetId,
                sheetRowNumber: target,
              );
              registry.shiftRowNumbers(target, 1);
              await sheets.writeRowAt(
                spreadsheetId: spreadsheetId,
                sheetTitle: sheetTitle,
                rowNumber: target,
                row: p.buildSheetRow(),
                rangeEndColumn: rangeEnd,
              );
              registry.markSynced(
                transactionId: p.txn.id,
                sheetRowNumber: target,
                syncedUpdatedAt: p.txn.updatedAt ?? p.txn.timestamp,
                paymentSourceId: p.source.id,
                type: p.txn.type,
                amountColumn: p.amountColumn,
              );
              appended++;
            } catch (e) {
              debugPrint('Insert fallback failed, appending: $e');
              final startRow = await sheets.appendRows(
                spreadsheetId: spreadsheetId,
                sheetTitle: sheetTitle,
                rows: [p.buildSheetRow()],
                rangeEndColumn: rangeEnd,
              );
              if (startRow != null) {
                registry.markSynced(
                  transactionId: p.txn.id,
                  sheetRowNumber: startRow,
                  syncedUpdatedAt: p.txn.updatedAt ?? p.txn.timestamp,
                  paymentSourceId: p.source.id,
                  type: p.txn.type,
                  amountColumn: p.amountColumn,
                );
                appended++;
              }
            }
            continue;
          }
          registry.adoptRowNumber(p.txn.id, rowNumber);
        }

        final snapshot = await loadSheetSnapshot();
        final sheetDate = SheetRowInserter.dateOnSheetRow(snapshot, rowNumber);
        final needsMove = sheetDate != null &&
            !SheetRowInserter.isSameDay(sheetDate, p.txn.timestamp);

        if (needsMove) {
          await sheets.deleteRows(
            spreadsheetId: spreadsheetId,
            sheetId: sheetId,
            sheetRowNumbers: [rowNumber],
          );
          registry.shiftRowNumbers(rowNumber + 1, -1);

          final localSnapshot = snapshot.map((r) => List<Object?>.from(r)).toList();
          SheetRowInserter.removeRowAt(localSnapshot, rowNumber);
          final target = SheetRowInserter.targetInsertRow(
            txnDate: p.txn.timestamp,
            sheetRows: localSnapshot,
          );

          await sheets.insertRowsAt(
            spreadsheetId: spreadsheetId,
            sheetId: sheetId,
            sheetRowNumber: target,
          );
          registry.shiftRowNumbers(target, 1);
          await sheets.writeRowAt(
            spreadsheetId: spreadsheetId,
            sheetTitle: sheetTitle,
            rowNumber: target,
            row: p.buildSheetRow(),
            rangeEndColumn: rangeEnd,
          );
          registry.markSynced(
            transactionId: p.txn.id,
            sheetRowNumber: target,
            syncedUpdatedAt: p.txn.updatedAt ?? p.txn.timestamp,
            paymentSourceId: p.source.id,
            type: p.txn.type,
            amountColumn: p.amountColumn,
          );
          moved++;
          sheetSnapshot = null;
          continue;
        }

        final fullRow = p.buildSheetRow();
        updateRanges.addAll(
          SheetRowBuilder.buildUpdateRanges(
            sheetTitle: sheetTitle,
            rowNumber: rowNumber,
            fullRow: fullRow,
            amountColumn: p.amountColumn,
            metadataStartColumnIndex: metadataStartColumnIndex,
            clearAmountColumn: p.previousAmountColumn,
          ),
        );
        registry.markSynced(
          transactionId: p.txn.id,
          sheetRowNumber: rowNumber,
          syncedUpdatedAt: p.txn.updatedAt ?? p.txn.timestamp,
          paymentSourceId: p.source.id,
          type: p.txn.type,
          amountColumn: p.amountColumn,
        );
        updated++;
      }

      if (updateRanges.isNotEmpty) {
        await sheets.batchUpdateRanges(
          spreadsheetId: spreadsheetId,
          ranges: updateRanges,
        );
      }

      await registry.save();

      final parts = <String>[];
      if (deleted > 0) parts.add('$deleted deleted');
      if (appended > 0) parts.add('$appended added');
      if (updated > 0) parts.add('$updated updated');
      if (moved > 0) parts.add('$moved moved');
      var sheetMsg = parts.isEmpty
          ? 'Sheet up to date — nothing to sync to $sheetTitle.'
          : 'Sheet sync to $sheetTitle: ${parts.join(', ')}.';
      if (usedAppendFallback) {
        sheetMsg += '\nNote: chronological insert unavailable; used bottom append.';
      }

      return SyncResult(
        success: true,
        message: '$sheetMsg\n$backupNote',
        appendedCount: appended,
        updatedCount: updated,
        deletedCount: deleted,
        movedCount: moved,
        driveFolderId: folderId,
        googleEmail: account.email,
      );
    } catch (e, st) {
      debugPrint('Sync failed: $e\n$st');
      return SyncResult(
        success: false,
        message: 'Sync failed: $e\n\n'
            'Ensure your Google account has Editor access to the spreadsheet '
            'and you allowed Sheets permission when signing in.',
      );
    }
  }
}
