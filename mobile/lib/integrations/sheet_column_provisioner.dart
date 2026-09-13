import 'package:googleapis/sheets/v4.dart' as gsheets;
import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/integrations/google_sync.dart';
import 'package:spendwise_mobile/integrations/sheet_column_letters.dart';
import 'package:spendwise_mobile/integrations/sheet_range.dart';

/// Inserts Credit / Debit / Balance columns in Google Sheet for new payment sources.
class SheetColumnProvisioner {
  SheetColumnProvisioner({
    required this.db,
    required this.sheets,
  });

  final AppDatabase db;
  final SheetsSyncService sheets;

  static const accountColumnWidth = 3;
  static const metadataFieldCount = 27;

  /// Ensures every active source has sheet columns; returns updated sync state.
  Future<SyncStateModel> ensureAllSources({
    required SyncStateModel syncState,
  }) async {
    var state = syncState;
    final missing = await db.getPaymentSourcesMissingSheetMapping();
    for (final source in missing) {
      state = await _provisionSource(source: source, syncState: state);
    }
    return state;
  }

  Future<PaymentSourceModel> ensureForSourceId({
    required String sourceId,
    required SyncStateModel syncState,
  }) async {
    final source = await db.getPaymentSource(sourceId);
    if (source == null) {
      throw StateError('Payment source not found');
    }
    if (source.hasSheetMapping) return source;
    await _provisionSource(source: source, syncState: syncState);
    return (await db.getPaymentSource(sourceId))!;
  }

  Future<SyncStateModel> _provisionSource({
    required PaymentSourceModel source,
    required SyncStateModel syncState,
  }) async {
    if (source.hasSheetMapping) return syncState;

    final sheetTitle = await sheets.resolveSheetTitle(
      spreadsheetId: syncState.sheetId,
      gid: syncState.sheetGid,
    );
    final resolvedTitle =
        sheetTitle.isNotEmpty ? sheetTitle : syncState.sheetName;
    final sheetId = await sheets.resolveSheetId(
      spreadsheetId: syncState.sheetId,
      gid: syncState.sheetGid,
    );

    final insertAt = syncState.metadataStartColumnIndex;
    await sheets.insertColumns(
      spreadsheetId: syncState.sheetId,
      sheetId: sheetId,
      startIndex: insertAt,
      columnCount: accountColumnWidth,
    );

    final creditCol = SheetColumnLetters.indexToColumnLetter(insertAt);
    final debitCol = SheetColumnLetters.indexToColumnLetter(insertAt + 1);
    final balanceCol = SheetColumnLetters.indexToColumnLetter(insertAt + 2);
    final thirdHeader =
        source.sourceTypeKey == 'CREDIT_CARD' ? 'Bill Total' : 'Balance';

    await sheets.batchUpdateRanges(
      spreadsheetId: syncState.sheetId,
      ranges: [
        gsheets.ValueRange(
          range: formatSheetRange(resolvedTitle, '${creditCol}1'),
          values: [
            [source.name],
          ],
        ),
        gsheets.ValueRange(
          range: formatSheetRange(resolvedTitle, '${creditCol}2:${balanceCol}2'),
          values: [
            ['Credit', 'Debit', thirdHeader],
          ],
        ),
      ],
    );

    await db.upsertPaymentSource(
      source.copyWith(
        sheetCreditColumn: creditCol,
        sheetDebitColumn: debitCol,
        sheetBalanceColumn: balanceCol,
      ),
    );

    final newState = syncState.copyWith(
      metadataStartColumnIndex: insertAt + accountColumnWidth,
    );
    await db.saveSyncState(newState);
    return newState;
  }

  static String appendRangeEndColumn(int metadataStartColumnIndex) {
    final lastIndex = metadataStartColumnIndex + metadataFieldCount - 1;
    return SheetColumnLetters.indexToColumnLetter(lastIndex);
  }
}
