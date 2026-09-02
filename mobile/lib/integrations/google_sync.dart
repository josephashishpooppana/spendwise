import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/sheet_row_builder.dart';

const _scopes = [
  sheets.SheetsApi.spreadsheetsScope,
  drive.DriveApi.driveFileScope,
];

class PendingSheetRow {
  const PendingSheetRow({
    required this.txn,
    required this.source,
    this.suffix = '',
  });

  final TransactionModel txn;
  final PaymentSourceModel source;
  final String suffix;
}

class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? signIn})
      : _signIn = signIn ??
            GoogleSignIn(
              scopes: _scopes,
            );

  final GoogleSignIn _signIn;

  GoogleSignInAccount? get currentUser => _signIn.currentUser;

  Future<GoogleSignInAccount?> signIn() => _signIn.signIn();

  Future<void> signOut() => _signIn.signOut();

  Future<GoogleSignInAccount?> signInSilently() => _signIn.signInSilently();

  Future<sheets.SheetsApi?> getSheetsApi() async {
    final client = await _signIn.authenticatedClient();
    if (client == null) return null;
    return sheets.SheetsApi(client);
  }

  Future<drive.DriveApi?> getDriveApi() async {
    final client = await _signIn.authenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }
}

class DriveSyncService {
  DriveSyncService(this._auth);

  final GoogleAuthService _auth;

  Future<String?> uploadBackup({
    required String fileName,
    required String jsonContent,
    String? folderId,
  }) async {
    final api = await _auth.getDriveApi();
    if (api == null) return null;

    final bytes = utf8.encode(jsonContent);
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

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
    if (api == null) return null;

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

  Future<String?> resolveSheetTitle({
    required String spreadsheetId,
    required String gid,
  }) async {
    final api = await _auth.getSheetsApi();
    if (api == null) return null;

    final spreadsheet = await api.spreadsheets.get(spreadsheetId);
    for (final sheet in spreadsheet.sheets ?? []) {
      if ('${sheet.properties?.sheetId}' == gid) {
        return sheet.properties?.title;
      }
    }
    return spreadsheet.sheets?.first.properties?.title;
  }

  Future<bool> appendRows({
    required String spreadsheetId,
    required String sheetTitle,
    required List<List<Object?>> rows,
  }) async {
    if (rows.isEmpty) return true;

    final api = await _auth.getSheetsApi();
    if (api == null) return false;

    const range = 'Sheet1!A:AS';
    final request = sheets.ValueRange(values: rows);
    await api.spreadsheets.values.append(
      request,
      spreadsheetId,
      range.replaceFirst('Sheet1', sheetTitle),
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );
    return true;
  }
}

class SyncResult {
  const SyncResult({
    required this.success,
    required this.message,
    this.exportedCount = 0,
    this.driveFolderId,
    this.googleEmail,
  });

  final bool success;
  final String message;
  final int exportedCount;
  final String? driveFolderId;
  final String? googleEmail;
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
    required String spreadsheetId,
    required String sheetGid,
    required String fallbackSheetName,
    String? driveFolderId,
  }) async {
    try {
      final account = await auth.signInSilently() ?? await auth.signIn();
      if (account == null) {
        return const SyncResult(success: false, message: 'Google sign-in cancelled');
      }

      final folderId = driveFolderId ?? await drive.ensureBackupFolder();
      final json = await exportJson();
      final fileName =
          'spendwise-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json';
      await drive.uploadBackup(
        fileName: fileName,
        jsonContent: json,
        folderId: folderId,
      );

      final pending = await pendingRows();
      var sheetTitle = await sheets.resolveSheetTitle(
        spreadsheetId: spreadsheetId,
        gid: sheetGid,
      );
      sheetTitle ??= fallbackSheetName;

      final rows = pending
          .map(
            (p) => SheetRowBuilder.buildRow(
              transaction: p.txn,
              source: p.source,
              descriptionSuffix: p.suffix,
            ),
          )
          .toList();

      if (rows.isNotEmpty) {
        await sheets.appendRows(
          spreadsheetId: spreadsheetId,
          sheetTitle: sheetTitle,
          rows: rows,
        );
      }

      return SyncResult(
        success: true,
        message: 'Synced ${rows.length} transaction(s) to sheet',
        exportedCount: rows.length,
        driveFolderId: folderId,
        googleEmail: account.email,
      );
    } catch (e, st) {
      debugPrint('Sync failed: $e\n$st');
      return SyncResult(success: false, message: 'Sync failed: $e');
    }
  }
}
