import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/data/seed_data.dart';
import 'package:spendwise_mobile/integrations/sheet_column_letters.dart';

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static AppDatabase? _instance;
  static Future<AppDatabase>? _opening;

  static Future<AppDatabase> open({String? path}) async {
    if (_instance != null) return _instance!;
    _opening ??= _openOnce(path);
    try {
      return await _opening!;
    } catch (e) {
      _opening = null;
      rethrow;
    }
  }

  static Future<AppDatabase> _openOnce(String? path) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'spendwise.db');
    final db = await openDatabase(
      dbPath,
      version: 4,
      onCreate: (database, version) async {
        await _createSchema(database);
        await SeedData.seed(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            'ALTER TABLE bill_splits ADD COLUMN my_share REAL',
          );
        }
        if (oldVersion < 3) {
          await database.execute('''
            CREATE TABLE split_settlements (
              id TEXT PRIMARY KEY,
              bill_split_id TEXT NOT NULL,
              contact_id TEXT NOT NULL,
              amount REAL NOT NULL,
              payment_source_id TEXT NOT NULL,
              income_transaction_id TEXT NOT NULL,
              paid_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await database.execute(
            'ALTER TABLE payment_sources ADD COLUMN sheet_credit_column TEXT',
          );
          await database.execute(
            'ALTER TABLE payment_sources ADD COLUMN sheet_debit_column TEXT',
          );
          await database.execute(
            'ALTER TABLE payment_sources ADD COLUMN sheet_balance_column TEXT',
          );
          await database.execute(
            'ALTER TABLE sync_state ADD COLUMN metadata_start_column_index INTEGER NOT NULL DEFAULT 26',
          );
          await _backfillLegacySheetColumns(database);
        }
      },
    );
    _instance = AppDatabase._(db);
    return _instance!;
  }

  static Future<AppDatabase> openMemory() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 4,
      onCreate: (database, version) async {
        await _createSchema(database);
        await SeedData.seed(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            'ALTER TABLE bill_splits ADD COLUMN my_share REAL',
          );
        }
        if (oldVersion < 3) {
          await database.execute('''
            CREATE TABLE split_settlements (
              id TEXT PRIMARY KEY,
              bill_split_id TEXT NOT NULL,
              contact_id TEXT NOT NULL,
              amount REAL NOT NULL,
              payment_source_id TEXT NOT NULL,
              income_transaction_id TEXT NOT NULL,
              paid_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await database.execute(
            'ALTER TABLE payment_sources ADD COLUMN sheet_credit_column TEXT',
          );
          await database.execute(
            'ALTER TABLE payment_sources ADD COLUMN sheet_debit_column TEXT',
          );
          await database.execute(
            'ALTER TABLE payment_sources ADD COLUMN sheet_balance_column TEXT',
          );
          await database.execute(
            'ALTER TABLE sync_state ADD COLUMN metadata_start_column_index INTEGER NOT NULL DEFAULT 26',
          );
          await _backfillLegacySheetColumns(database);
        }
      },
    );
    return AppDatabase._(db);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE source_types (
        id TEXT PRIMARY KEY,
        key TEXT NOT NULL,
        label TEXT NOT NULL,
        is_builtin INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE payment_methods (
        id TEXT PRIMARY KEY,
        key TEXT,
        name TEXT NOT NULL,
        is_builtin INTEGER NOT NULL DEFAULT 1,
        allowed_source_types TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE payment_apps (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        supported_method_ids TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE payment_sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        bank_name TEXT,
        source_type_key TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        linked_bank_source_id TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sheet_credit_column TEXT,
        sheet_debit_column TEXT,
        sheet_balance_column TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE payment_app_sources (
        payment_app_id TEXT NOT NULL,
        payment_method_id TEXT NOT NULL,
        payment_source_id TEXT NOT NULL,
        PRIMARY KEY (payment_app_id, payment_method_id, payment_source_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        timestamp TEXT NOT NULL,
        payment_source_id TEXT NOT NULL,
        payment_method_id TEXT,
        payment_app_id TEXT,
        notes TEXT,
        cashback_received REAL NOT NULL DEFAULT 0,
        is_automated INTEGER NOT NULL DEFAULT 0,
        cashback_from_expense_id TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE cashbacks (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        percentage REAL,
        reward_points INTEGER,
        credit_source_id TEXT,
        reward_app_id TEXT,
        income_transaction_id TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone_number TEXT,
        email TEXT,
        upi_id TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        member_ids TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE bill_splits (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL UNIQUE,
        split_type TEXT NOT NULL,
        split_details TEXT NOT NULL,
        group_id TEXT,
        is_settled INTEGER NOT NULL DEFAULT 0,
        my_share REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE split_settlements (
        id TEXT PRIMARY KEY,
        bill_split_id TEXT NOT NULL,
        contact_id TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_source_id TEXT NOT NULL,
        income_transaction_id TEXT NOT NULL,
        paid_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        last_synced_at TEXT,
        exported_transaction_ids TEXT NOT NULL DEFAULT '',
        drive_folder_id TEXT,
        google_account_email TEXT,
        sheet_id TEXT NOT NULL,
        sheet_gid TEXT NOT NULL,
        sheet_name TEXT NOT NULL,
        metadata_start_column_index INTEGER NOT NULL DEFAULT 26
      )
    ''');
  }

  Database get raw => _db;

  Future<List<PaymentSourceModel>> getPaymentSources({bool all = false}) async {
    final rows = await _db.query(
      'payment_sources',
      where: all ? null : 'is_active = 1',
      orderBy: 'name ASC',
    );
    return rows.map(PaymentSourceModel.fromMap).toList();
  }

  Future<PaymentSourceModel?> getPaymentSource(String id) async {
    final rows =
        await _db.query('payment_sources', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return PaymentSourceModel.fromMap(rows.first);
  }

  Future<void> upsertPaymentSource(PaymentSourceModel source) async {
    await _db.insert(
      'payment_sources',
      source.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePaymentSource(String id) async {
    await _db.delete('payment_sources', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSourceBalance(String id, double balance) async {
    await _db.update(
      'payment_sources',
      {'balance': balance},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<PaymentAppModel>> getPaymentApps({bool all = false}) async {
    final rows = await _db.query(
      'payment_apps',
      where: all ? null : 'is_active = 1',
      orderBy: 'name ASC',
    );
    return rows.map(PaymentAppModel.fromMap).toList();
  }

  Future<void> upsertPaymentApp(PaymentAppModel app) async {
    await _db.insert(
      'payment_apps',
      app.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePaymentApp(String id) async {
    await _db.delete('payment_apps', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final rows =
        await _db.query('payment_methods', orderBy: 'name ASC');
    return rows.map(PaymentMethodModel.fromMap).toList();
  }

  Future<void> upsertPaymentMethod(PaymentMethodModel method) async {
    await _db.insert(
      'payment_methods',
      method.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePaymentMethod(String id) async {
    await _db.delete('payment_methods', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PaymentAppSourceLink>> getAppSourceLinks({
    String? appId,
  }) async {
    final rows = await _db.query(
      'payment_app_sources',
      where: appId != null ? 'payment_app_id = ?' : null,
      whereArgs: appId != null ? [appId] : null,
    );
    return rows.map(PaymentAppSourceLink.fromMap).toList();
  }

  Future<void> linkAppSource(PaymentAppSourceLink link) async {
    await _db.insert(
      'payment_app_sources',
      link.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> unlinkAppSource({
    required String appId,
    required String sourceId,
    String? methodId,
  }) async {
    if (methodId != null) {
      await _db.delete(
        'payment_app_sources',
        where: 'payment_app_id = ? AND payment_source_id = ? AND payment_method_id = ?',
        whereArgs: [appId, sourceId, methodId],
      );
    } else {
      await _db.delete(
        'payment_app_sources',
        where: 'payment_app_id = ? AND payment_source_id = ?',
        whereArgs: [appId, sourceId],
      );
    }
  }

  Future<List<TransactionModel>> getTransactions({
    TransactionType? type,
    String? category,
    String? search,
    int? limit,
    int? offset,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (type != null) {
      where.add('type = ?');
      args.add(type.name);
    }
    if (category != null && category.isNotEmpty) {
      where.add('category = ?');
      args.add(category);
    }
    if (search != null && search.isNotEmpty) {
      where.add('(description LIKE ? OR category LIKE ? OR notes LIKE ?)');
      args.addAll(['%$search%', '%$search%', '%$search%']);
    }

    final rows = await _db.query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<TransactionModel?> getTransaction(String id) async {
    final rows =
        await _db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return TransactionModel.fromMap(rows.first);
  }

  Future<bool> transactionExists(String id) async {
    final rows = await _db.query(
      'transactions',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> countTransactions() async {
    final result =
        await _db.rawQuery('SELECT COUNT(*) as c FROM transactions');
    return (result.first['c'] as int?) ?? 0;
  }

  Future<void> clearAllTransactions() async {
    await _db.delete('split_settlements');
    await _db.delete('cashbacks');
    await _db.delete('bill_splits');
    await _db.delete('transactions');
  }

  Future<void> resetAllSourceBalances() async {
    await _db.update('payment_sources', {'balance': 0});
  }

  Future<void> insertTransaction(TransactionModel txn) async {
    await _db.insert(
      'transactions',
      txn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransaction(TransactionModel txn) async {
    await _db.update(
      'transactions',
      txn.toMap(),
      where: 'id = ?',
      whereArgs: [txn.id],
    );
  }

  Future<void> deleteTransaction(String id) async {
    final split = await getBillSplitForTransaction(id);
    if (split != null) {
      await deleteBillSplit(split.id);
    } else {
      await _db.delete('bill_splits', where: 'transaction_id = ?', whereArgs: [id]);
    }
    await _db.delete('transactions', where: 'id = ?', whereArgs: [id]);
    await _db.delete('cashbacks', where: 'transaction_id = ?', whereArgs: [id]);
  }

  Future<List<CashbackModel>> getCashbacksForTransaction(String txnId) async {
    final rows = await _db.query(
      'cashbacks',
      where: 'transaction_id = ?',
      whereArgs: [txnId],
    );
    return rows.map(CashbackModel.fromMap).toList();
  }

  Future<void> insertCashback(CashbackModel cb) async {
    await _db.insert('cashbacks', cb.toMap());
  }

  Future<void> deleteCashbacksForTransaction(String txnId) async {
    await _db.delete('cashbacks', where: 'transaction_id = ?', whereArgs: [txnId]);
  }

  Future<List<ContactModel>> getContacts() async {
    final rows = await _db.query('contacts', orderBy: 'name ASC');
    return rows.map(ContactModel.fromMap).toList();
  }

  Future<void> upsertContact(ContactModel contact) async {
    await _db.insert(
      'contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteContact(String id) async {
    await _db.delete('contacts', where: 'id = ?', whereArgs: [id]);
    final groups = await getGroups();
    for (final group in groups) {
      if (!group.memberIds.contains(id)) continue;
      await upsertGroup(
        GroupModel(
          id: group.id,
          name: group.name,
          memberIds: group.memberIds.where((m) => m != id).toList(),
        ),
      );
    }
  }

  Future<List<GroupModel>> getGroups() async {
    final rows = await _db.query('groups', orderBy: 'name ASC');
    return rows.map(GroupModel.fromMap).toList();
  }

  Future<void> upsertGroup(GroupModel group) async {
    await _db.insert(
      'groups',
      group.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteGroup(String id) async {
    await _db.delete('groups', where: 'id = ?', whereArgs: [id]);
  }

  Future<BillSplitModel?> getBillSplitForTransaction(String txnId) async {
    final rows = await _db.query(
      'bill_splits',
      where: 'transaction_id = ?',
      whereArgs: [txnId],
    );
    if (rows.isEmpty) return null;
    return BillSplitModel.fromMap(rows.first);
  }

  Future<List<BillSplitModel>> getBillSplits() async {
    final rows = await _db.query('bill_splits');
    return rows.map(BillSplitModel.fromMap).toList();
  }

  Future<void> upsertBillSplit(BillSplitModel split) async {
    await _db.insert(
      'bill_splits',
      split.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSettlementIncomeTransaction(String incomeTransactionId) async {
    await _db.delete(
      'split_settlements',
      where: 'income_transaction_id = ?',
      whereArgs: [incomeTransactionId],
    );
    await _db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [incomeTransactionId],
    );
  }

  Future<void> deleteBillSplit(String id) async {
    await _db.delete(
      'split_settlements',
      where: 'bill_split_id = ?',
      whereArgs: [id],
    );
    await _db.delete('bill_splits', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SplitSettlementModel>> getSplitSettlementsForBillSplit(
    String billSplitId,
  ) async {
    final rows = await _db.query(
      'split_settlements',
      where: 'bill_split_id = ?',
      whereArgs: [billSplitId],
      orderBy: 'paid_at ASC',
    );
    return rows.map(SplitSettlementModel.fromMap).toList();
  }

  Future<List<SplitSettlementModel>> getAllSplitSettlements() async {
    final rows = await _db.query('split_settlements', orderBy: 'paid_at ASC');
    return rows.map(SplitSettlementModel.fromMap).toList();
  }

  Future<void> insertSplitSettlement(SplitSettlementModel settlement) async {
    await _db.insert(
      'split_settlements',
      settlement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, BillSplitModel>> getBillSplitsByTransactionId() async {
    final splits = await getBillSplits();
    return {for (final s in splits) s.transactionId: s};
  }

  Future<SyncStateModel> getSyncState() async {
    final rows = await _db.query('sync_state', where: 'id = 1');
    if (rows.isEmpty) {
      const state = SyncStateModel();
      await _db.insert('sync_state', state.toMap());
      return state;
    }
    return SyncStateModel.fromMap(rows.first);
  }

  Future<void> saveSyncState(SyncStateModel state) async {
    await _db.insert(
      'sync_state',
      state.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>> exportAll() async {
    Future<List<Map<String, Object?>>> table(String name) =>
        _db.query(name);

    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'sourceTypes': await table('source_types'),
      'paymentMethods': await table('payment_methods'),
      'paymentApps': await table('payment_apps'),
      'paymentSources': await table('payment_sources'),
      'paymentAppSources': await table('payment_app_sources'),
      'transactions': await table('transactions'),
      'cashbacks': await table('cashbacks'),
      'contacts': await table('contacts'),
      'groups': await table('groups'),
      'billSplits': await table('bill_splits'),
      'splitSettlements': await table('split_settlements'),
      'syncState': await table('sync_state'),
    };
  }

  Future<String> exportAllJson() async {
    return jsonEncode(await exportAll());
  }

  Future<List<PaymentSourceModel>> getPaymentSourcesMissingSheetMapping({
    bool all = false,
  }) async {
    final sources = await getPaymentSources(all: all);
    return sources.where((s) => !s.hasSheetMapping).toList();
  }

  static Future<void> _backfillLegacySheetColumns(Database database) async {
    final rows = await database.query('payment_sources');
    for (final row in rows) {
      final name = row['name'] as String;
      final cols = LegacySheetColumnBackfill.columnsForName(name);
      if (cols == null) continue;
      await database.update(
        'payment_sources',
        {
          'sheet_credit_column': cols.$1,
          'sheet_debit_column': cols.$2,
          'sheet_balance_column': cols.$3,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }
}
