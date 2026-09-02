import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/transaction_service.dart';
import 'package:spendwise_mobile/integrations/google_sync.dart';

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  return AppDatabase.open();
});

final transactionServiceProvider = FutureProvider<TransactionService>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return TransactionService(db);
});

final paymentSourcesProvider = FutureProvider<List<PaymentSourceModel>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getPaymentSources();
});

final paymentAppsProvider = FutureProvider<List<PaymentAppModel>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getPaymentApps();
});

final paymentMethodsProvider =
    FutureProvider<List<PaymentMethodModel>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getPaymentMethods();
});

final transactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getTransactions(limit: 200);
});

final contactsProvider = FutureProvider<List<ContactModel>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getContacts();
});

final groupsProvider = FutureProvider<List<GroupModel>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getGroups();
});

final billSplitsProvider = FutureProvider<List<BillSplitModel>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getBillSplits();
});

final syncStateProvider = FutureProvider<SyncStateModel>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getSyncState();
});

final googleAuthProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final auth = ref.watch(googleAuthProvider);
  return SyncService(
    auth: auth,
    drive: DriveSyncService(auth),
    sheets: SheetsSyncService(auth),
  );
});

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final txns = await db.getTransactions();
  final sources = await db.getPaymentSources();

  var income = 0.0;
  var expense = 0.0;
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month);

  for (final t in txns) {
    if (t.timestamp.isBefore(monthStart)) continue;
    if (t.type == TransactionType.income) {
      income += t.amount;
    } else {
      expense += t.netExpenseAmount;
    }
  }

  return DashboardStats(
    monthIncome: income,
    monthExpense: expense,
    totalBalance: sources.fold(0.0, (sum, s) => sum + s.balance),
    recentTransactions: txns.take(8).toList(),
  );
});

class DashboardStats {
  const DashboardStats({
    required this.monthIncome,
    required this.monthExpense,
    required this.totalBalance,
    required this.recentTransactions,
  });

  final double monthIncome;
  final double monthExpense;
  final double totalBalance;
  final List<TransactionModel> recentTransactions;
}
