import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:spendwise_mobile/data/models/models.dart';

/// Tracks which app transactions are on which Google Sheet rows.
/// Stored as JSON beside the local SQLite database.
class SheetSyncEntry {
  const SheetSyncEntry({
    required this.sheetRowNumber,
    required this.syncedUpdatedAt,
    this.paymentSourceId,
    this.transactionType,
    this.amountColumn,
  });

  final int sheetRowNumber;
  final DateTime syncedUpdatedAt;
  final String? paymentSourceId;
  final String? transactionType;
  final String? amountColumn;

  bool get hasSheetRow => sheetRowNumber > 0;

  Map<String, dynamic> toJson() => {
        'sheetRowNumber': sheetRowNumber,
        'syncedUpdatedAt': syncedUpdatedAt.toIso8601String(),
        if (paymentSourceId != null) 'paymentSourceId': paymentSourceId,
        if (transactionType != null) 'transactionType': transactionType,
        if (amountColumn != null) 'amountColumn': amountColumn,
      };

  factory SheetSyncEntry.fromJson(Map<String, dynamic> json) => SheetSyncEntry(
        sheetRowNumber: json['sheetRowNumber'] as int? ?? 0,
        syncedUpdatedAt: DateTime.parse(json['syncedUpdatedAt'] as String),
        paymentSourceId: json['paymentSourceId'] as String?,
        transactionType: json['transactionType'] as String?,
        amountColumn: json['amountColumn'] as String?,
      );

  SheetSyncEntry copyWith({
    int? sheetRowNumber,
    DateTime? syncedUpdatedAt,
    String? paymentSourceId,
    String? transactionType,
    String? amountColumn,
  }) =>
      SheetSyncEntry(
        sheetRowNumber: sheetRowNumber ?? this.sheetRowNumber,
        syncedUpdatedAt: syncedUpdatedAt ?? this.syncedUpdatedAt,
        paymentSourceId: paymentSourceId ?? this.paymentSourceId,
        transactionType: transactionType ?? this.transactionType,
        amountColumn: amountColumn ?? this.amountColumn,
      );
}

enum SheetSyncAction { append, update, skip }

class PlannedSheetSync {
  const PlannedSheetSync({
    required this.action,
    required this.transactionId,
    this.sheetRowNumber,
    this.previousEntry,
  });

  final SheetSyncAction action;
  final String transactionId;
  final int? sheetRowNumber;
  final SheetSyncEntry? previousEntry;
}

class SheetSyncRegistry {
  SheetSyncRegistry(this._filePath);

  final String _filePath;
  Map<String, SheetSyncEntry> _entries = {};

  static Future<SheetSyncRegistry> open({String? dbPath}) async {
    final base = dbPath ?? p.join(await getDatabasesPath(), 'spendwise.db');
    final registry = SheetSyncRegistry('$base_sheet_sync.json');
    await registry._load();
    return registry;
  }

  Map<String, SheetSyncEntry> get entries => Map.unmodifiable(_entries);

  SheetSyncEntry? entryFor(String transactionId) => _entries[transactionId];

  PlannedSheetSync plan(TransactionModel txn) {
    final updated = txn.updatedAt ?? txn.timestamp;
    final existing = _entries[txn.id];
    if (existing == null) {
      return PlannedSheetSync(
        action: SheetSyncAction.append,
        transactionId: txn.id,
      );
    }
    if (updated.isAfter(existing.syncedUpdatedAt)) {
      return PlannedSheetSync(
        action: SheetSyncAction.update,
        transactionId: txn.id,
        sheetRowNumber: existing.hasSheetRow ? existing.sheetRowNumber : null,
        previousEntry: existing,
      );
    }
    return PlannedSheetSync(
      action: SheetSyncAction.skip,
      transactionId: txn.id,
      sheetRowNumber: existing.sheetRowNumber,
      previousEntry: existing,
    );
  }

  void markSynced({
    required String transactionId,
    required int sheetRowNumber,
    required DateTime syncedUpdatedAt,
    required String paymentSourceId,
    required TransactionType type,
    required String amountColumn,
  }) {
    _entries[transactionId] = SheetSyncEntry(
      sheetRowNumber: sheetRowNumber,
      syncedUpdatedAt: syncedUpdatedAt,
      paymentSourceId: paymentSourceId,
      transactionType: type.name,
      amountColumn: amountColumn,
    );
  }

  void remove(String transactionId) {
    _entries.remove(transactionId);
  }

  /// Legacy rows exported before row tracking existed.
  void migrateExportedIds(Iterable<String> transactionIds) {
    final now = DateTime.fromMillisecondsSinceEpoch(0);
    for (final id in transactionIds) {
      _entries.putIfAbsent(
        id,
        () => SheetSyncEntry(
          sheetRowNumber: 0,
          syncedUpdatedAt: now,
        ),
      );
    }
  }

  void adoptRowNumber(String transactionId, int sheetRowNumber) {
    final existing = _entries[transactionId];
    if (existing == null) return;
    _entries[transactionId] = existing.copyWith(sheetRowNumber: sheetRowNumber);
  }

  Future<void> save() async {
    final file = File(_filePath);
    await file.parent.create(recursive: true);
    final payload = {
      'version': 1,
      'updatedAt': DateTime.now().toIso8601String(),
      'entries': _entries.map((k, v) => MapEntry(k, v.toJson())),
    };
    await file.writeAsString(jsonEncode(payload));
  }

  Map<String, dynamic> toExportJson() => {
        'filePath': _filePath,
        'entries': _entries.map((k, v) => MapEntry(k, v.toJson())),
      };

  Future<void> _load() async {
    final file = File(_filePath);
    if (!await file.exists()) return;
    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final raw = map['entries'] as Map<String, dynamic>? ?? {};
      _entries = raw.map(
        (k, v) => MapEntry(
          k,
          SheetSyncEntry.fromJson(v as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      _entries = {};
    }
  }
}
