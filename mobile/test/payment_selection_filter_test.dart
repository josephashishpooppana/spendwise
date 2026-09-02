import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/payment_selection_filter.dart';

void main() {
  const upi = PaymentMethodModel(
    id: 'pm-upi',
    key: 'UPI',
    name: 'UPI',
    allowedSourceTypeKeys: ['CREDIT_CARD', 'DEBIT_CARD'],
  );
  const cash = PaymentMethodModel(
    id: 'pm-cash',
    key: 'CASH',
    name: 'Cash',
    allowedSourceTypeKeys: ['CASH'],
  );

  const gpay = PaymentAppModel(
    id: 'app-gpay',
    name: 'Google Pay',
    supportedMethodIds: ['pm-upi'],
  );

  const icici = PaymentSourceModel(
    id: 'src-bank',
    name: 'ICICI',
    sourceTypeKey: 'BANK',
  );
  const hdfcCc = PaymentSourceModel(
    id: 'src-cc',
    name: 'HDFC CC',
    sourceTypeKey: 'CREDIT_CARD',
  );
  const cashHand = PaymentSourceModel(
    id: 'src-cash',
    name: 'Cash',
    sourceTypeKey: 'CASH',
  );

  test('no app selected returns all methods and unfiltered sources by type', () {
    final methods = PaymentSelectionFilter.methodsForApp(
      allMethods: [upi, cash],
      appId: null,
      app: null,
    );
    expect(methods.length, 2);

    final sources = PaymentSelectionFilter.sourcesForExpense(
      allSources: [icici, hdfcCc, cashHand],
      appLinks: const [],
      appId: null,
      method: upi,
    );
    expect(sources.map((s) => s.id), ['src-cc']);
  });

  test('app selected filters methods by supportedMethodIds', () {
    final methods = PaymentSelectionFilter.methodsForApp(
      allMethods: [upi, cash],
      appId: gpay.id,
      app: gpay,
    );
    expect(methods.map((m) => m.id), ['pm-upi']);
  });

  test('app selected filters sources by app links and method types', () {
    const links = [
      PaymentAppSourceLink(
        paymentAppId: 'app-gpay',
        paymentMethodId: 'pm-upi',
        paymentSourceId: 'src-cc',
      ),
    ];

    final sources = PaymentSelectionFilter.sourcesForExpense(
      allSources: [icici, hdfcCc, cashHand],
      appLinks: links,
      appId: 'app-gpay',
      method: upi,
    );
    expect(sources.map((s) => s.id), ['src-cc']);
  });

  test('income excludes debit cards', () {
    const debit = PaymentSourceModel(
      id: 'src-dc',
      name: 'Debit',
      sourceTypeKey: 'DEBIT_CARD',
    );
    final sources = PaymentSelectionFilter.sourcesForIncome([
      icici,
      debit,
    ]);
    expect(sources.map((s) => s.id), ['src-bank']);
  });
}
