import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/source_balance_calculator.dart';
import 'package:spendwise_mobile/domain/services/split_balance_helper.dart';
import 'package:spendwise_mobile/domain/services/split_settlement_service.dart';
import 'package:spendwise_mobile/domain/services/transaction_service.dart';
import 'package:spendwise_mobile/integrations/google_sync.dart';
import 'package:spendwise_mobile/integrations/sheet_column_provisioner.dart';
import 'package:spendwise_mobile/integrations/sheet_import_service.dart';
import 'package:spendwise_mobile/integrations/sheet_sync_registry.dart';

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

final paymentAppSourceLinksProvider =
    FutureProvider<List<PaymentAppSourceLink>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getAppSourceLinks();
});

final transactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getTransactions();
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

final splitSettlementsProvider =
    FutureProvider<List<SplitSettlementModel>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getAllSplitSettlements();
});

final splitSettlementServiceProvider =
    FutureProvider<SplitSettlementService>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return SplitSettlementService(db);
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

final sheetColumnProvisionerProvider =
    FutureProvider<SheetColumnProvisioner>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final auth = ref.watch(googleAuthProvider);
  return SheetColumnProvisioner(
    db: db,
    sheets: SheetsSyncService(auth),
  );
});

final sheetSyncRegistryProvider = FutureProvider<SheetSyncRegistry>((ref) async {
  return SheetSyncRegistry.open();
});

final sheetImportServiceProvider = FutureProvider<SheetImportService>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final auth = ref.watch(googleAuthProvider);
  final registry = await ref.watch(sheetSyncRegistryProvider.future);
  return SheetImportService(
    auth: auth,
    sheets: SheetsSyncService(auth),
    db: db,
    registry: registry,
  );
});

final descriptionFavoritesProvider =
    FutureProvider<List<DescriptionFavorite>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return db.getDescriptionFavorites();
});

final descriptionSuggestionsProvider = FutureProvider<List<String>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final favorites = await db.getDescriptionFavorites();
  final frequent = await db.getFrequentDescriptions(limit: 10);
  final seen = <String>{};
  final result = <String>[];
  for (final f in favorites) {
    final key = f.text.toLowerCase();
    if (seen.add(key)) result.add(f.text);
  }
  for (final d in frequent) {
    final key = d.toLowerCase();
    if (seen.add(key)) result.add(d);
  }
  return result;
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
    totalBalance: SourceBalanceCalculator.netTotalBalance(sources),
    recentTransactions: txns.take(8).toList(),
  );
});

final analyticsStatsProvider = FutureProvider<AnalyticsStats>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final txns = await db.getTransactions();
  final sources = await db.getPaymentSources();
  final splits = await db.getBillSplits();
  final settlements = await db.getAllSplitSettlements();
  final sourcesById = {for (final s in sources) s.id: s};

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month);
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));

  var monthIncome = 0.0;
  var monthExpense = 0.0;
  var monthCashback = 0.0;
  var allTimeCashback = 0.0;
  TransactionModel? largestExpense;
  var expenseLast30Days = 0.0;
  var daysWithExpense = 0;

  final categoryTotals = <String, double>{};
  final monthCategoryTotals = <String, double>{};
  final descriptionTotals = <String, double>{};
  final sourceExpenseTotals = <String, double>{};
  final monthlyTrend = <MonthlyTrendPoint>[];

  for (final t in txns) {
    if (t.type == TransactionType.income) {
      if (!t.timestamp.isBefore(monthStart)) monthIncome += t.amount;
    } else {
      final net = t.netExpenseAmount;
      if (!t.timestamp.isBefore(monthStart)) monthExpense += net;
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + net;
      if (!t.timestamp.isBefore(monthStart)) {
        monthCategoryTotals[t.category] =
            (monthCategoryTotals[t.category] ?? 0) + net;
      }
      descriptionTotals[t.description] =
          (descriptionTotals[t.description] ?? 0) + net;
      sourceExpenseTotals[t.paymentSourceId] =
          (sourceExpenseTotals[t.paymentSourceId] ?? 0) + net;
      if (largestExpense == null || net > largestExpense!.netExpenseAmount) {
        largestExpense = t;
      }
      if (!t.timestamp.isBefore(thirtyDaysAgo)) {
        expenseLast30Days += net;
        daysWithExpense++;
      }
      allTimeCashback += t.cashbackReceived;
      if (!t.timestamp.isBefore(monthStart)) {
        monthCashback += t.cashbackReceived;
      }
    }
  }

  for (var i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    var inc = 0.0;
    var exp = 0.0;
    for (final t in txns) {
      if (t.timestamp.isBefore(month) || !t.timestamp.isBefore(nextMonth)) {
        continue;
      }
      if (t.type == TransactionType.income) {
        inc += t.amount;
      } else {
        exp += t.netExpenseAmount;
      }
    }
    monthlyTrend.add(
      MonthlyTrendPoint(
        label: '${month.month}/${month.year % 100}',
        income: inc,
        expense: exp,
      ),
    );
  }

  final topDescriptions = descriptionTotals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final spendingBySource = sourceExpenseTotals.entries.map((e) {
    final source = sourcesById[e.key];
    return SourceSpendEntry(
      sourceName: source?.name ?? e.key,
      amount: e.value,
    );
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));

  final creditCardStats = sources
      .where((s) => s.sourceTypeKey == 'CREDIT_CARD')
      .map((s) {
        final utilization = s.creditLimit != null && s.creditLimit! > 0
            ? (s.balance / s.creditLimit!) * 100
            : null;
        int? daysToStatement;
        if (s.statementDay != null) {
          final today = now.day;
          daysToStatement = s.statementDay! >= today
              ? s.statementDay! - today
              : (DateTime(now.year, now.month + 1, 0).day - today) +
                  s.statementDay!;
        }
        return CreditCardStat(
          name: s.name,
          billTotal: s.balance,
          creditLimit: s.creditLimit,
          utilizationPercent: utilization,
          daysToStatement: daysToStatement,
        );
      })
      .toList();

  var splitOutstanding = 0.0;
  for (final split in splits) {
    final related = settlements.where((s) => s.billSplitId == split.id).toList();
    splitOutstanding += SplitBalanceHelper.totalOutstanding(
      split: split,
      settlements: related,
    );
  }

  return AnalyticsStats(
    monthIncome: monthIncome,
    monthExpense: monthExpense,
    netSaved: monthIncome - monthExpense,
    netBalance: SourceBalanceCalculator.netTotalBalance(sources),
    categoryTotals: categoryTotals,
    monthCategoryTotals: monthCategoryTotals,
    monthlyTrend: monthlyTrend,
    topDescriptions: topDescriptions.take(10).toList(),
    spendingBySource: spendingBySource,
    monthCashback: monthCashback,
    allTimeCashback: allTimeCashback,
    creditCardStats: creditCardStats,
    splitOutstanding: splitOutstanding,
    largestExpense: largestExpense,
    avgDailySpend30Days:
        daysWithExpense > 0 ? expenseLast30Days / 30 : 0,
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

class AnalyticsStats {
  const AnalyticsStats({
    required this.monthIncome,
    required this.monthExpense,
    required this.netSaved,
    required this.netBalance,
    required this.categoryTotals,
    required this.monthCategoryTotals,
    required this.monthlyTrend,
    required this.topDescriptions,
    required this.spendingBySource,
    required this.monthCashback,
    required this.allTimeCashback,
    required this.creditCardStats,
    required this.splitOutstanding,
    required this.largestExpense,
    required this.avgDailySpend30Days,
  });

  final double monthIncome;
  final double monthExpense;
  final double netSaved;
  final double netBalance;
  final Map<String, double> categoryTotals;
  final Map<String, double> monthCategoryTotals;
  final List<MonthlyTrendPoint> monthlyTrend;
  final List<MapEntry<String, double>> topDescriptions;
  final List<SourceSpendEntry> spendingBySource;
  final double monthCashback;
  final double allTimeCashback;
  final List<CreditCardStat> creditCardStats;
  final double splitOutstanding;
  final TransactionModel? largestExpense;
  final double avgDailySpend30Days;
}

class MonthlyTrendPoint {
  const MonthlyTrendPoint({
    required this.label,
    required this.income,
    required this.expense,
  });

  final String label;
  final double income;
  final double expense;
}

class SourceSpendEntry {
  const SourceSpendEntry({required this.sourceName, required this.amount});

  final String sourceName;
  final double amount;
}

class CreditCardStat {
  const CreditCardStat({
    required this.name,
    required this.billTotal,
    this.creditLimit,
    this.utilizationPercent,
    this.daysToStatement,
  });

  final String name;
  final double billTotal;
  final double? creditLimit;
  final double? utilizationPercent;
  final int? daysToStatement;
}
