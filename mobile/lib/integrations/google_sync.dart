import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/core/google_config.dart';
import 'package:spendwise_mobile/integrations/drive_backup_naming.dart';
import 'package:spendwise_mobile/integrations/sheet_range.dart';
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

  /// Ensures Sheets/Drive scopes are granted and returns an authenticated client.
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

  Future<sheets.SheetsApi> getSheetsApi() async {
    final client = await requireAuthClient();
    return sheets.SheetsApi(client);
  }

  Future<drive.DriveApi> getDriveApi() async {
    final client = await requireAuthClient();
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

  /// One backup file per ISO week. Replaces the existing file if sync runs again
  /// within the same week; a new file is created automatically when the week changes.
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
        fields: 'files(id)',
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

  Future<bool> appendRows({
    required String spreadsheetId,
    required String sheetTitle,
    required List<List<Object?>> rows,
  }) async {
    if (rows.isEmpty) return true;

    final api = await _auth.getSheetsApi();

    final range = formatSheetRange(sheetTitle, 'A:AS');
    final request = sheets.ValueRange(values: rows);
    await api.spreadsheets.values.append(
      request,
      spreadsheetId,
      range,
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

      final pending = await pendingRows();
      var sheetTitle = await sheets.resolveSheetTitle(
        spreadsheetId: spreadsheetId,
        gid: sheetGid,
      );
      if (sheetTitle.isEmpty) {
        sheetTitle = fallbackSheetName;
      }

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

      final sheetMsg = rows.isEmpty
          ? 'No new transactions to append to $sheetTitle.'
          : 'Appended ${rows.length} transaction(s) to $sheetTitle.';

      return SyncResult(
        success: true,
        message: '$sheetMsg\n$backupNote',
        exportedCount: rows.length,
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
