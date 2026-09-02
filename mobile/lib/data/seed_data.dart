import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:spendwise_mobile/data/models/models.dart';

class SeedData {
  static const _uuid = Uuid();

  static Future<void> seed(Database db) async {
    const sourceTypes = [
      SourceTypeModel(id: 'st-bank', key: 'BANK', label: 'Bank Account'),
      SourceTypeModel(id: 'st-cc', key: 'CREDIT_CARD', label: 'Credit Card'),
      SourceTypeModel(id: 'st-dc', key: 'DEBIT_CARD', label: 'Debit Card'),
      SourceTypeModel(id: 'st-wallet', key: 'WALLET', label: 'Wallet'),
      SourceTypeModel(id: 'st-cash', key: 'CASH', label: 'Cash'),
    ];

    for (final st in sourceTypes) {
      await db.insert('source_types', st.toMap());
    }

    const methods = [
      PaymentMethodModel(
        id: 'pm-upi',
        key: 'UPI',
        name: 'UPI Payment',
        allowedSourceTypeKeys: ['CREDIT_CARD', 'DEBIT_CARD'],
      ),
      PaymentMethodModel(
        id: 'pm-cash',
        key: 'CASH',
        name: 'Cash',
        allowedSourceTypeKeys: ['CASH'],
      ),
      PaymentMethodModel(
        id: 'pm-atm',
        key: 'ATM',
        name: 'ATM Withdrawal',
        allowedSourceTypeKeys: ['BANK'],
      ),
      PaymentMethodModel(
        id: 'pm-cc',
        key: 'CREDIT_CARD',
        name: 'Credit Card',
        allowedSourceTypeKeys: ['CREDIT_CARD'],
      ),
      PaymentMethodModel(
        id: 'pm-dc',
        key: 'DEBIT_CARD',
        name: 'Debit Card',
        allowedSourceTypeKeys: ['DEBIT_CARD'],
      ),
      PaymentMethodModel(
        id: 'pm-wallet',
        key: 'WALLET',
        name: 'Wallet',
        allowedSourceTypeKeys: ['WALLET'],
      ),
      PaymentMethodModel(
        id: 'pm-nb',
        key: 'NET_BANKING',
        name: 'Net Banking',
        allowedSourceTypeKeys: ['BANK'],
      ),
      PaymentMethodModel(
        id: 'pm-transfer',
        key: 'TRANSFER',
        name: 'Bank Transfer',
        allowedSourceTypeKeys: ['BANK'],
      ),
      PaymentMethodModel(
        id: 'pm-check',
        key: 'CHECK',
        name: 'Check',
        allowedSourceTypeKeys: ['BANK'],
      ),
      PaymentMethodModel(
        id: 'pm-other',
        key: 'OTHER',
        name: 'Other',
        allowedSourceTypeKeys: [
          'BANK',
          'CREDIT_CARD',
          'DEBIT_CARD',
          'WALLET',
          'CASH',
        ],
      ),
    ];

    for (final m in methods) {
      await db.insert('payment_methods', m.toMap());
    }

    // Default payment sources matching user's Google Sheet accounts
    final iciciId = _uuid.v4();
    final bobId = _uuid.v4();
    final hdfcId = _uuid.v4();

    final sources = [
      PaymentSourceModel(id: iciciId, name: 'ICICI Bank', sourceTypeKey: 'BANK', balance: 0),
      PaymentSourceModel(id: bobId, name: 'BOB', sourceTypeKey: 'BANK', balance: 0),
      PaymentSourceModel(id: hdfcId, name: 'HDFC', sourceTypeKey: 'BANK', balance: 0),
      PaymentSourceModel(
        id: _uuid.v4(),
        name: 'Federal Bank Credit Card',
        sourceTypeKey: 'CREDIT_CARD',
        balance: 0,
      ),
      PaymentSourceModel(
        id: _uuid.v4(),
        name: 'HDFC Bank Credit Card',
        sourceTypeKey: 'CREDIT_CARD',
        balance: 0,
      ),
      PaymentSourceModel(
        id: _uuid.v4(),
        name: 'ICICI Bank Credit Card',
        sourceTypeKey: 'CREDIT_CARD',
        balance: 0,
      ),
      PaymentSourceModel(
        id: _uuid.v4(),
        name: 'Cash In Hand',
        sourceTypeKey: 'CASH',
        balance: 0,
      ),
    ];

    for (final s in sources) {
      await db.insert('payment_sources', s.toMap());
    }

    await db.insert('sync_state', const SyncStateModel().toMap());
  }
}
