import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/balance_service.dart';
import 'package:spendwise_mobile/domain/services/cashback_service.dart';
import 'package:uuid/uuid.dart';

class CreateTransactionInput {
  const CreateTransactionInput({
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.timestamp,
    required this.paymentSourceId,
    this.paymentMethodId,
    this.paymentAppId,
    this.notes,
    this.cashbackEntries = const [],
    this.split,
  });

  final TransactionType type;
  final double amount;
  final String category;
  final String description;
  final DateTime timestamp;
  final String paymentSourceId;
  final String? paymentMethodId;
  final String? paymentAppId;
  final String? notes;
  final List<CashbackEntryInput> cashbackEntries;
  final BillSplitModel? split;
}

class TransactionService {
  TransactionService(
    this._db, {
    BalanceService? balanceService,
    CashbackService? cashbackService,
    Uuid? uuid,
  })  : _balanceService = balanceService ?? BalanceService(),
        _cashbackService = cashbackService ?? CashbackService(),
        _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final BalanceService _balanceService;
  final CashbackService _cashbackService;
  final Uuid _uuid;

  Future<TransactionModel> create(CreateTransactionInput input) async {
    if (input.type == TransactionType.expense &&
        (input.paymentMethodId == null || input.paymentMethodId!.isEmpty)) {
      throw ArgumentError('Payment method is required for expenses');
    }

    final txnId = _uuid.v4();
    var cashbackReceived = 0.0;
    final incomeTxns = <TransactionModel>[];
    final cashbacks = <CashbackModel>[];

    if (input.type == TransactionType.expense &&
        input.cashbackEntries.isNotEmpty) {
      final expense = TransactionModel(
        id: txnId,
        type: input.type,
        amount: input.amount,
        category: input.category,
        description: input.description,
        timestamp: input.timestamp,
        paymentSourceId: input.paymentSourceId,
        paymentMethodId: input.paymentMethodId,
        paymentAppId: input.paymentAppId,
        notes: input.notes,
      );
      final result = _cashbackService.processEntries(
        expense: expense,
        entries: input.cashbackEntries,
        defaultCreditSourceId: input.paymentSourceId,
      );
      cashbackReceived = result.totalCashback;
      cashbacks.addAll(result.cashbacks);
      incomeTxns.addAll(result.incomeTransactions);
    }

    final txn = TransactionModel(
      id: txnId,
      type: input.type,
      amount: input.amount,
      category: input.category,
      description: input.description,
      timestamp: input.timestamp,
      paymentSourceId: input.paymentSourceId,
      paymentMethodId: input.paymentMethodId,
      paymentAppId: input.paymentAppId,
      notes: input.notes,
      cashbackReceived: cashbackReceived,
      updatedAt: DateTime.now(),
    );

    await _db.insertTransaction(txn);
    for (final cb in cashbacks) {
      await _db.insertCashback(cb);
    }
    for (final income in incomeTxns) {
      await _db.insertTransaction(income);
    }

    if (input.split != null) {
      await _db.upsertBillSplit(input.split!.copyWith(transactionId: txnId));
    }

    await _applyBalances(
      txn: txn,
      incomeTxns: incomeTxns,
      reverse: false,
    );

    return txn;
  }

  Future<TransactionModel> update(
    String id,
    CreateTransactionInput input,
  ) async {
    final existing = await _db.getTransaction(id);
    if (existing == null) throw StateError('Transaction not found');

    await _reverseTransaction(existing);

    await _db.deleteCashbacksForTransaction(id);
    for (final cb in await _db.getCashbacksForTransaction(id)) {
      if (cb.incomeTransactionId != null) {
        await _reverseTransactionById(cb.incomeTransactionId!);
        await _db.deleteTransaction(cb.incomeTransactionId!);
      }
    }

    var cashbackReceived = 0.0;
    final incomeTxns = <TransactionModel>[];
    final cashbacks = <CashbackModel>[];

    if (input.type == TransactionType.expense &&
        input.cashbackEntries.isNotEmpty) {
      final expense = TransactionModel(
        id: id,
        type: input.type,
        amount: input.amount,
        category: input.category,
        description: input.description,
        timestamp: input.timestamp,
        paymentSourceId: input.paymentSourceId,
        paymentMethodId: input.paymentMethodId,
        paymentAppId: input.paymentAppId,
        notes: input.notes,
      );
      final result = _cashbackService.processEntries(
        expense: expense,
        entries: input.cashbackEntries,
        defaultCreditSourceId: input.paymentSourceId,
      );
      cashbackReceived = result.totalCashback;
      cashbacks.addAll(result.cashbacks);
      incomeTxns.addAll(result.incomeTransactions);
    }

    final updated = TransactionModel(
      id: id,
      type: input.type,
      amount: input.amount,
      category: input.category,
      description: input.description,
      timestamp: input.timestamp,
      paymentSourceId: input.paymentSourceId,
      paymentMethodId: input.paymentMethodId,
      paymentAppId: input.paymentAppId,
      notes: input.notes,
      cashbackReceived: cashbackReceived,
      updatedAt: DateTime.now(),
    );

    await _db.updateTransaction(updated);
    for (final cb in cashbacks) {
      await _db.insertCashback(cb);
    }
    for (final income in incomeTxns) {
      await _db.insertTransaction(income);
    }

    if (input.split != null) {
      await _db.upsertBillSplit(input.split!.copyWith(transactionId: id));
    } else {
      final existingSplit = await _db.getBillSplitForTransaction(id);
      if (existingSplit != null) {
        await _db.deleteBillSplit(existingSplit.id);
      }
    }

    await _applyBalances(txn: updated, incomeTxns: incomeTxns, reverse: false);
    return updated;
  }

  Future<void> delete(String id) async {
    final txn = await _db.getTransaction(id);
    if (txn == null) return;

    for (final cb in await _db.getCashbacksForTransaction(id)) {
      if (cb.incomeTransactionId != null) {
        await _reverseTransactionById(cb.incomeTransactionId!);
        await _db.deleteTransaction(cb.incomeTransactionId!);
      }
    }

    await _reverseTransaction(txn);
    await _db.deleteTransaction(id);
  }

  Future<void> _reverseTransaction(TransactionModel txn) async {
    final incomeTxns = <TransactionModel>[];
    for (final cb in await _db.getCashbacksForTransaction(txn.id)) {
      if (cb.incomeTransactionId != null) {
        final inc = await _db.getTransaction(cb.incomeTransactionId!);
        if (inc != null) incomeTxns.add(inc);
      }
    }
    await _applyBalances(txn: txn, incomeTxns: incomeTxns, reverse: true);
  }

  Future<void> _reverseTransactionById(String id) async {
    final txn = await _db.getTransaction(id);
    if (txn != null) {
      await _applyBalances(txn: txn, incomeTxns: const [], reverse: true);
    }
  }

  Future<void> _applyBalances({
    required TransactionModel txn,
    required List<TransactionModel> incomeTxns,
    required bool reverse,
  }) async {
    final sources = {
      for (final s in await _db.getPaymentSources(all: true)) s.id: s,
    };

    final netAmount = txn.type == TransactionType.expense
        ? txn.netExpenseAmount
        : txn.amount;

    final source = sources[txn.paymentSourceId];
    if (source != null) {
      _balanceService.applyDelta(
        source: source,
        amount: netAmount,
        type: txn.type,
        sourcesById: sources,
        reverse: reverse,
      );
    }

    for (final income in incomeTxns) {
      final creditSource = sources[income.paymentSourceId];
      if (creditSource != null) {
        _balanceService.applyDelta(
          source: creditSource,
          amount: income.amount,
          type: TransactionType.income,
          sourcesById: sources,
          reverse: reverse,
        );
      }
    }

    for (final source in sources.values) {
      await _db.updateSourceBalance(source.id, source.balance);
    }
  }
}
