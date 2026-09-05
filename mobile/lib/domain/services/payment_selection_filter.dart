import 'package:spendwise_mobile/data/models/models.dart';

/// Mirrors web frontend cascade: app → methods → sources.
class PaymentSelectionFilter {
  PaymentSelectionFilter._();

  /// When [appId] is null, returns all methods (no filtering).
  static List<PaymentMethodModel> methodsForApp({
    required List<PaymentMethodModel> allMethods,
    String? appId,
    PaymentAppModel? app,
  }) {
    if (appId == null || app == null) return allMethods;
    if (app.supportedMethodIds.isEmpty) return allMethods;
    final allowed = app.supportedMethodIds.toSet();
    return allMethods.where((m) => allowed.contains(m.id)).toList();
  }

  /// When [appId] is null, returns active sources only (no app/method filtering).
  static List<PaymentSourceModel> sourcesForExpense({
    required List<PaymentSourceModel> allSources,
    required List<PaymentAppSourceLink> appLinks,
    String? appId,
    PaymentMethodModel? method,
  }) {
    var result = allSources.where((s) => s.isActive).toList();

    if (appId != null) {
      final linkedIds = appLinks
          .where((l) => l.paymentAppId == appId)
          .map((l) => l.paymentSourceId)
          .toSet();
      if (linkedIds.isNotEmpty) {
        result = result.where((s) => linkedIds.contains(s.id)).toList();
      }
    }

    if (method != null && method.allowedSourceTypeKeys.isNotEmpty) {
      final types = method.allowedSourceTypeKeys.toSet();
      result = result.where((s) => types.contains(s.sourceTypeKey)).toList();
    }

    return result;
  }

  static List<PaymentSourceModel> sourcesForIncome(
    List<PaymentSourceModel> allSources,
  ) {
    return allSources
        .where((s) => s.isActive && s.sourceTypeKey != 'DEBIT_CARD')
        .toList();
  }

  static List<PaymentSourceModel> sourcesWithSufficientFunds({
    required List<PaymentSourceModel> allSources,
    required List<PaymentAppSourceLink> appLinks,
    required Map<String, PaymentSourceModel> sourcesById,
    String? appId,
    PaymentMethodModel? method,
    required double amount,
  }) {
    if (amount <= 0) {
      return sourcesForExpense(
        allSources: allSources,
        appLinks: appLinks,
        appId: appId,
        method: method,
      );
    }

    return sourcesForExpense(
      allSources: allSources,
      appLinks: appLinks,
      appId: appId,
      method: method,
    ).where((source) {
      final available = _availableForExpense(source, sourcesById);
      return available >= amount;
    }).toList();
  }

  static double _availableForExpense(
    PaymentSourceModel source,
    Map<String, PaymentSourceModel> sourcesById,
  ) {
    switch (source.sourceTypeKey) {
      case 'CREDIT_CARD':
        if (source.creditLimit == null) return double.infinity;
        return source.creditLimit! - source.balance;
      case 'DEBIT_CARD':
        final bank = sourcesById[source.linkedBankSourceId];
        return bank?.balance ?? 0;
      default:
        return source.balance;
    }
  }

  static String? pickFirstId<T>(List<T> items, String? Function(T) idOf) {
    if (items.isEmpty) return null;
    return idOf(items.first);
  }

  static bool containsId(List<PaymentMethodModel> items, String? id) {
    if (id == null) return false;
    return items.any((m) => m.id == id);
  }

  static bool containsSourceId(List<PaymentSourceModel> items, String? id) {
    if (id == null) return false;
    return items.any((s) => s.id == id);
  }
}
