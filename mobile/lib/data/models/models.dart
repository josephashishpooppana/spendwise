class SourceTypeModel {
  const SourceTypeModel({
    required this.id,
    required this.key,
    required this.label,
    this.isBuiltin = true,
  });

  final String id;
  final String key;
  final String label;
  final bool isBuiltin;

  Map<String, Object?> toMap() => {
        'id': id,
        'key': key,
        'label': label,
        'is_builtin': isBuiltin ? 1 : 0,
      };

  factory SourceTypeModel.fromMap(Map<String, Object?> map) => SourceTypeModel(
        id: map['id'] as String,
        key: map['key'] as String,
        label: map['label'] as String,
        isBuiltin: (map['is_builtin'] as int? ?? 1) == 1,
      );
}

class PaymentMethodModel {
  const PaymentMethodModel({
    required this.id,
    this.key,
    required this.name,
    this.isBuiltIn = true,
    this.allowedSourceTypeKeys = const [],
  });

  final String id;
  final String? key;
  final String name;
  final bool isBuiltIn;
  final List<String> allowedSourceTypeKeys;

  Map<String, Object?> toMap() => {
        'id': id,
        'key': key,
        'name': name,
        'is_builtin': isBuiltIn ? 1 : 0,
        'allowed_source_types': allowedSourceTypeKeys.join(','),
      };

  factory PaymentMethodModel.fromMap(Map<String, Object?> map) =>
      PaymentMethodModel(
        id: map['id'] as String,
        key: map['key'] as String?,
        name: map['name'] as String,
        isBuiltIn: (map['is_builtin'] as int? ?? 1) == 1,
        allowedSourceTypeKeys: (map['allowed_source_types'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
      );
}

class PaymentAppModel {
  const PaymentAppModel({
    required this.id,
    required this.name,
    this.supportedMethodIds = const [],
    this.isActive = true,
  });

  final String id;
  final String name;
  final List<String> supportedMethodIds;
  final bool isActive;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'supported_method_ids': supportedMethodIds.join(','),
        'is_active': isActive ? 1 : 0,
      };

  factory PaymentAppModel.fromMap(Map<String, Object?> map) => PaymentAppModel(
        id: map['id'] as String,
        name: map['name'] as String,
        supportedMethodIds: (map['supported_method_ids'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );
}

class PaymentSourceModel {
  const PaymentSourceModel({
    required this.id,
    required this.name,
    required this.sourceTypeKey,
    this.bankName,
    this.balance = 0,
    this.linkedBankSourceId,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? bankName;
  final String sourceTypeKey;
  final double balance;
  final String? linkedBankSourceId;
  final bool isActive;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'bank_name': bankName,
        'source_type_key': sourceTypeKey,
        'balance': balance,
        'linked_bank_source_id': linkedBankSourceId,
        'is_active': isActive ? 1 : 0,
      };

  factory PaymentSourceModel.fromMap(Map<String, Object?> map) =>
      PaymentSourceModel(
        id: map['id'] as String,
        name: map['name'] as String,
        bankName: map['bank_name'] as String?,
        sourceTypeKey: map['source_type_key'] as String,
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        linkedBankSourceId: map['linked_bank_source_id'] as String?,
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );

  PaymentSourceModel copyWith({
    String? name,
    String? bankName,
    String? sourceTypeKey,
    double? balance,
    String? linkedBankSourceId,
    bool? isActive,
  }) =>
      PaymentSourceModel(
        id: id,
        name: name ?? this.name,
        bankName: bankName ?? this.bankName,
        sourceTypeKey: sourceTypeKey ?? this.sourceTypeKey,
        balance: balance ?? this.balance,
        linkedBankSourceId: linkedBankSourceId ?? this.linkedBankSourceId,
        isActive: isActive ?? this.isActive,
      );
}

class PaymentAppSourceLink {
  const PaymentAppSourceLink({
    required this.paymentAppId,
    required this.paymentMethodId,
    required this.paymentSourceId,
  });

  final String paymentAppId;
  final String paymentMethodId;
  final String paymentSourceId;

  Map<String, Object?> toMap() => {
        'payment_app_id': paymentAppId,
        'payment_method_id': paymentMethodId,
        'payment_source_id': paymentSourceId,
      };

  factory PaymentAppSourceLink.fromMap(Map<String, Object?> map) =>
      PaymentAppSourceLink(
        paymentAppId: map['payment_app_id'] as String,
        paymentMethodId: map['payment_method_id'] as String,
        paymentSourceId: map['payment_source_id'] as String,
      );
}

enum TransactionType { income, expense }

enum CashbackKind { fixed, percentage, rewardPoints }

class CashbackModel {
  const CashbackModel({
    required this.id,
    required this.transactionId,
    required this.kind,
    this.amount = 0,
    this.percentage,
    this.rewardPoints,
    this.creditSourceId,
    this.rewardAppId,
    this.incomeTransactionId,
  });

  final String id;
  final String transactionId;
  final CashbackKind kind;
  final double amount;
  final double? percentage;
  final int? rewardPoints;
  final String? creditSourceId;
  final String? rewardAppId;
  final String? incomeTransactionId;

  Map<String, Object?> toMap() => {
        'id': id,
        'transaction_id': transactionId,
        'kind': kind.name,
        'amount': amount,
        'percentage': percentage,
        'reward_points': rewardPoints,
        'credit_source_id': creditSourceId,
        'reward_app_id': rewardAppId,
        'income_transaction_id': incomeTransactionId,
      };

  factory CashbackModel.fromMap(Map<String, Object?> map) => CashbackModel(
        id: map['id'] as String,
        transactionId: map['transaction_id'] as String,
        kind: CashbackKind.values.byName(map['kind'] as String),
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        percentage: (map['percentage'] as num?)?.toDouble(),
        rewardPoints: map['reward_points'] as int?,
        creditSourceId: map['credit_source_id'] as String?,
        rewardAppId: map['reward_app_id'] as String?,
        incomeTransactionId: map['income_transaction_id'] as String?,
      );
}

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.timestamp,
    required this.paymentSourceId,
    this.paymentMethodId,
    this.paymentAppId,
    this.notes,
    this.cashbackReceived = 0,
    this.isAutomated = false,
    this.cashbackFromExpenseId,
    this.updatedAt,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final String category;
  final String description;
  final DateTime timestamp;
  final String paymentSourceId;
  final String? paymentMethodId;
  final String? paymentAppId;
  final String? notes;
  final double cashbackReceived;
  final bool isAutomated;
  final String? cashbackFromExpenseId;
  final DateTime? updatedAt;

  double get netExpenseAmount =>
      type == TransactionType.expense ? amount - cashbackReceived : amount;

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'payment_source_id': paymentSourceId,
        'payment_method_id': paymentMethodId,
        'payment_app_id': paymentAppId,
        'notes': notes,
        'cashback_received': cashbackReceived,
        'is_automated': isAutomated ? 1 : 0,
        'cashback_from_expense_id': cashbackFromExpenseId,
        'updated_at': (updatedAt ?? timestamp).toIso8601String(),
      };

  factory TransactionModel.fromMap(Map<String, Object?> map) => TransactionModel(
        id: map['id'] as String,
        type: TransactionType.values.byName(map['type'] as String),
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String,
        description: map['description'] as String? ?? '',
        timestamp: DateTime.parse(map['timestamp'] as String),
        paymentSourceId: map['payment_source_id'] as String,
        paymentMethodId: map['payment_method_id'] as String?,
        paymentAppId: map['payment_app_id'] as String?,
        notes: map['notes'] as String?,
        cashbackReceived: (map['cashback_received'] as num?)?.toDouble() ?? 0,
        isAutomated: (map['is_automated'] as int? ?? 0) == 1,
        cashbackFromExpenseId: map['cashback_from_expense_id'] as String?,
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : null,
      );

  TransactionModel copyWith({
    TransactionType? type,
    double? amount,
    String? category,
    String? description,
    DateTime? timestamp,
    String? paymentSourceId,
    String? paymentMethodId,
    String? paymentAppId,
    String? notes,
    double? cashbackReceived,
    bool? isAutomated,
    DateTime? updatedAt,
  }) =>
      TransactionModel(
        id: id,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        description: description ?? this.description,
        timestamp: timestamp ?? this.timestamp,
        paymentSourceId: paymentSourceId ?? this.paymentSourceId,
        paymentMethodId: paymentMethodId ?? this.paymentMethodId,
        paymentAppId: paymentAppId ?? this.paymentAppId,
        notes: notes ?? this.notes,
        cashbackReceived: cashbackReceived ?? this.cashbackReceived,
        isAutomated: isAutomated ?? this.isAutomated,
        cashbackFromExpenseId: cashbackFromExpenseId,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}

class ContactModel {
  const ContactModel({
    required this.id,
    required this.name,
    this.phoneNumber = '',
    this.email = '',
    this.upiId = '',
  });

  final String id;
  final String name;
  final String phoneNumber;
  final String email;
  final String upiId;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone_number': phoneNumber,
        'email': email,
        'upi_id': upiId,
      };

  factory ContactModel.fromMap(Map<String, Object?> map) => ContactModel(
        id: map['id'] as String,
        name: map['name'] as String,
        phoneNumber: map['phone_number'] as String? ?? '',
        email: map['email'] as String? ?? '',
        upiId: map['upi_id'] as String? ?? '',
      );
}

class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    this.memberIds = const [],
  });

  final String id;
  final String name;
  final List<String> memberIds;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'member_ids': memberIds.join(','),
      };

  factory GroupModel.fromMap(Map<String, Object?> map) => GroupModel(
        id: map['id'] as String,
        name: map['name'] as String,
        memberIds: (map['member_ids'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
      );
}

enum SplitType { equal, custom }

class BillSplitModel {
  const BillSplitModel({
    required this.id,
    required this.transactionId,
    required this.splitType,
    required this.splitDetails,
    this.groupId,
    this.isSettled = false,
  });

  final String id;
  final String transactionId;
  final SplitType splitType;
  final Map<String, double> splitDetails;
  final String? groupId;
  final bool isSettled;

  Map<String, Object?> toMap() => {
        'id': id,
        'transaction_id': transactionId,
        'split_type': splitType.name,
        'split_details': splitDetails.entries
            .map((e) => '${e.key}:${e.value}')
            .join('|'),
        'group_id': groupId,
        'is_settled': isSettled ? 1 : 0,
      };

  factory BillSplitModel.fromMap(Map<String, Object?> map) {
    final raw = map['split_details'] as String? ?? '';
    final details = <String, double>{};
    for (final part in raw.split('|')) {
      if (part.isEmpty) continue;
      final idx = part.indexOf(':');
      if (idx <= 0) continue;
      details[part.substring(0, idx)] =
          double.tryParse(part.substring(idx + 1)) ?? 0;
    }
    return BillSplitModel(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String,
      splitType: SplitType.values.byName(map['split_type'] as String),
      splitDetails: details,
      groupId: map['group_id'] as String?,
      isSettled: (map['is_settled'] as int? ?? 0) == 1,
    );
  }
}

class SheetColumnMapping {
  const SheetColumnMapping({
    required this.sourceNamePattern,
    required this.creditColumn,
    required this.debitColumn,
  });

  final String sourceNamePattern;
  final String creditColumn;
  final String debitColumn;
}

class SyncStateModel {
  const SyncStateModel({
    this.lastSyncedAt,
    this.exportedTransactionIds = const [],
    this.driveFolderId,
    this.googleAccountEmail,
    this.sheetId = '1ObWgYGp928tIva0FvWZyIcFNvLRkkG0gTRHrgyQ9JbU',
    this.sheetGid = '1320698518',
    this.sheetName = 'Sheet1',
  });

  final DateTime? lastSyncedAt;
  final List<String> exportedTransactionIds;
  final String? driveFolderId;
  final String? googleAccountEmail;
  final String sheetId;
  final String sheetGid;
  final String sheetName;

  Map<String, Object?> toMap() => {
        'id': 1,
        'last_synced_at': lastSyncedAt?.toIso8601String(),
        'exported_transaction_ids': exportedTransactionIds.join(','),
        'drive_folder_id': driveFolderId,
        'google_account_email': googleAccountEmail,
        'sheet_id': sheetId,
        'sheet_gid': sheetGid,
        'sheet_name': sheetName,
      };

  factory SyncStateModel.fromMap(Map<String, Object?> map) => SyncStateModel(
        lastSyncedAt: map['last_synced_at'] != null
            ? DateTime.tryParse(map['last_synced_at'] as String)
            : null,
        exportedTransactionIds:
            (map['exported_transaction_ids'] as String? ?? '')
                .split(',')
                .where((s) => s.isNotEmpty)
                .toList(),
        driveFolderId: map['drive_folder_id'] as String?,
        googleAccountEmail: map['google_account_email'] as String?,
        sheetId: map['sheet_id'] as String? ??
            '1ObWgYGp928tIva0FvWZyIcFNvLRkkG0gTRHrgyQ9JbU',
        sheetGid: map['sheet_gid'] as String? ?? '1320698518',
        sheetName: map['sheet_name'] as String? ?? 'Sheet1',
      );

  SyncStateModel copyWith({
    DateTime? lastSyncedAt,
    List<String>? exportedTransactionIds,
    String? driveFolderId,
    String? googleAccountEmail,
  }) =>
      SyncStateModel(
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        exportedTransactionIds:
            exportedTransactionIds ?? this.exportedTransactionIds,
        driveFolderId: driveFolderId ?? this.driveFolderId,
        googleAccountEmail: googleAccountEmail ?? this.googleAccountEmail,
        sheetId: sheetId,
        sheetGid: sheetGid,
        sheetName: sheetName,
      );
}
