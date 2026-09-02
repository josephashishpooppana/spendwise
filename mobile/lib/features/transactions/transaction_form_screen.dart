import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/cashback_service.dart';
import 'package:spendwise_mobile/features/splits/split_settlement_widgets.dart';
import 'package:spendwise_mobile/domain/services/payment_selection_filter.dart';
import 'package:spendwise_mobile/domain/services/transaction_service.dart';
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transactionId});

  final String? transactionId;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  TransactionType _type = TransactionType.expense;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = 'other';
  DateTime _date = DateTime.now();
  String? _appId;
  String? _methodId;
  String? _sourceId;
  bool _loading = false;

  bool _cashbackEnabled = false;
  CashbackKind _cashbackKind = CashbackKind.fixed;
  final _cashbackAmountCtrl = TextEditingController();
  final _cashbackPctCtrl = TextEditingController();
  final _rewardPointsCtrl = TextEditingController();
  String? _cashbackCreditSourceId;
  String? _rewardAppId;

  @override
  void initState() {
    super.initState();
    if (widget.transactionId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final db = await ref.read(databaseProvider.future);
    final txn = await db.getTransaction(widget.transactionId!);
    if (txn == null || !mounted) return;
    setState(() {
      _type = txn.type;
      _amountCtrl.text = txn.amount.toString();
      _descCtrl.text = txn.description;
      _notesCtrl.text = txn.notes ?? '';
      _category = txn.category;
      _date = txn.timestamp;
      _appId = txn.paymentAppId;
      _methodId = txn.paymentMethodId;
      _sourceId = txn.paymentSourceId;
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    _cashbackAmountCtrl.dispose();
    _cashbackPctCtrl.dispose();
    _rewardPointsCtrl.dispose();
    super.dispose();
  }

  List<CashbackEntryInput> _cashbackEntries() {
    if (!_cashbackEnabled || _type != TransactionType.expense) return [];
    switch (_cashbackKind) {
      case CashbackKind.fixed:
        return [
          CashbackEntryInput(
            kind: CashbackKind.fixed,
            amount: double.tryParse(_cashbackAmountCtrl.text),
            creditSourceId: _cashbackCreditSourceId ?? _sourceId,
          ),
        ];
      case CashbackKind.percentage:
        return [
          CashbackEntryInput(
            kind: CashbackKind.percentage,
            percentage: double.tryParse(_cashbackPctCtrl.text),
            creditSourceId: _cashbackCreditSourceId ?? _sourceId,
          ),
        ];
      case CashbackKind.rewardPoints:
        return [
          CashbackEntryInput(
            kind: CashbackKind.rewardPoints,
            rewardPoints: int.tryParse(_rewardPointsCtrl.text),
            rewardAppId: _rewardAppId ?? _appId,
          ),
        ];
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sourceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a payment source')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final service = await ref.read(transactionServiceProvider.future);
      final input = CreateTransactionInput(
        type: _type,
        amount: double.parse(_amountCtrl.text),
        category: _category,
        description: _descCtrl.text.trim(),
        timestamp: _date,
        paymentSourceId: _sourceId!,
        paymentMethodId: _methodId,
        paymentAppId: _appId,
        notes: _notesCtrl.text.trim(),
        cashbackEntries: _cashbackEntries(),
      );

      if (widget.transactionId == null) {
        await service.create(input);
      } else {
        await service.update(widget.transactionId!, input);
      }

      ref.invalidate(transactionsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(paymentSourcesProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onAppChanged(String? appId) {
    final methods = ref.read(paymentMethodsProvider).valueOrNull ?? [];
    final sources = ref.read(paymentSourcesProvider).valueOrNull ?? [];
    final apps = ref.read(paymentAppsProvider).valueOrNull ?? [];
    final appLinks = ref.read(paymentAppSourceLinksProvider).valueOrNull ?? [];

    final app = appId == null
        ? null
        : apps.where((a) => a.id == appId).firstOrNull;

    final filteredMethods = PaymentSelectionFilter.methodsForApp(
      allMethods: methods,
      appId: appId,
      app: app,
    );

    var methodId = _methodId;
    if (!PaymentSelectionFilter.containsId(filteredMethods, methodId)) {
      methodId = PaymentSelectionFilter.pickFirstId(
        filteredMethods,
        (m) => m.id,
      );
    }

    final method = methodId == null
        ? null
        : methods.where((m) => m.id == methodId).firstOrNull;

    final filteredSources = PaymentSelectionFilter.sourcesForExpense(
      allSources: sources,
      appLinks: appLinks,
      appId: appId,
      method: method,
    );

    var sourceId = _sourceId;
    if (!PaymentSelectionFilter.containsSourceId(filteredSources, sourceId)) {
      sourceId = PaymentSelectionFilter.pickFirstId(
        filteredSources,
        (s) => s.id,
      );
    }

    setState(() {
      _appId = appId;
      _methodId = methodId;
      _sourceId = sourceId;
    });
  }

  void _onMethodChanged(String? methodId) {
    final methods = ref.read(paymentMethodsProvider).valueOrNull ?? [];
    final sources = ref.read(paymentSourcesProvider).valueOrNull ?? [];
    final appLinks = ref.read(paymentAppSourceLinksProvider).valueOrNull ?? [];

    final method = methodId == null
        ? null
        : methods.where((m) => m.id == methodId).firstOrNull;

    final filteredSources = PaymentSelectionFilter.sourcesForExpense(
      allSources: sources,
      appLinks: appLinks,
      appId: _appId,
      method: method,
    );

    var sourceId = _sourceId;
    if (!PaymentSelectionFilter.containsSourceId(filteredSources, sourceId)) {
      sourceId = PaymentSelectionFilter.pickFirstId(
        filteredSources,
        (s) => s.id,
      );
    }

    setState(() {
      _methodId = methodId;
      _sourceId = sourceId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(paymentSourcesProvider);
    final appsAsync = ref.watch(paymentAppsProvider);
    final methodsAsync = ref.watch(paymentMethodsProvider);
    final appLinksAsync = ref.watch(paymentAppSourceLinksProvider);

    final allMethods = methodsAsync.valueOrNull ?? [];
    final allSources = sourcesAsync.valueOrNull ?? [];
    final allApps = appsAsync.valueOrNull ?? [];
    final appLinks = appLinksAsync.valueOrNull ?? [];

    final selectedApp = _appId == null
        ? null
        : allApps.where((a) => a.id == _appId).firstOrNull;
    final selectedMethod = _methodId == null
        ? null
        : allMethods.where((m) => m.id == _methodId).firstOrNull;

    final filteredMethods = _type == TransactionType.expense
        ? PaymentSelectionFilter.methodsForApp(
            allMethods: allMethods,
            appId: _appId,
            app: selectedApp,
          )
        : <PaymentMethodModel>[];

    final filteredSources = _type == TransactionType.income
        ? PaymentSelectionFilter.sourcesForIncome(allSources)
        : PaymentSelectionFilter.sourcesForExpense(
            allSources: allSources,
            appLinks: appLinks,
            appId: _appId,
            method: selectedMethod,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transactionId == null ? 'New transaction' : 'Edit'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _category = _type == TransactionType.income
                    ? incomeCategories.first
                    : expenseCategories.first;
                if (_type == TransactionType.income) {
                  _appId = null;
                  _methodId = null;
                }
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter amount',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: (_type == TransactionType.income
                      ? incomeCategories
                      : expenseCategories)
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(Formatters.categoryLabel(c)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(Formatters.date.format(_date)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            if (_type == TransactionType.expense) ...[
              appsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (apps) => DropdownButtonFormField<String?>(
                  value: _appId,
                  decoration: const InputDecoration(labelText: 'Payment app'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...apps.map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ),
                  ],
                  onChanged: _onAppChanged,
                ),
              ),
              const SizedBox(height: 12),
              methodsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text('$e'),
                data: (_) => DropdownButtonFormField<String?>(
                  value: PaymentSelectionFilter.containsId(
                    filteredMethods,
                    _methodId,
                  )
                      ? _methodId
                      : null,
                  decoration: const InputDecoration(labelText: 'Payment method'),
                  items: filteredMethods
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.name),
                        ),
                      )
                      .toList(),
                  onChanged: _onMethodChanged,
                  validator: (v) =>
                      _type == TransactionType.expense && v == null
                          ? 'Required'
                          : null,
                ),
              ),
              const SizedBox(height: 12),
            ],
            sourcesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (_) {
                return DropdownButtonFormField<String?>(
                  value: PaymentSelectionFilter.containsSourceId(
                    filteredSources,
                    _sourceId,
                  )
                      ? _sourceId
                      : null,
                  decoration: InputDecoration(
                    labelText: _type == TransactionType.income
                        ? 'Credited to'
                        : 'Payment source',
                  ),
                  items: filteredSources
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '${s.name} (${Formatters.currency.format(s.balance)})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _sourceId = v),
                  validator: (v) => v == null ? 'Required' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            if (_type == TransactionType.expense) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Cashback / reward points'),
                value: _cashbackEnabled,
                onChanged: (v) => setState(() => _cashbackEnabled = v),
              ),
              if (_cashbackEnabled) ...[
                DropdownButtonFormField<CashbackKind>(
                  value: _cashbackKind,
                  decoration: const InputDecoration(labelText: 'Cashback type'),
                  items: const [
                    DropdownMenuItem(
                      value: CashbackKind.fixed,
                      child: Text('Fixed amount'),
                    ),
                    DropdownMenuItem(
                      value: CashbackKind.percentage,
                      child: Text('Percentage'),
                    ),
                    DropdownMenuItem(
                      value: CashbackKind.rewardPoints,
                      child: Text('Reward points'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _cashbackKind = v ?? _cashbackKind),
                ),
                if (_cashbackKind == CashbackKind.fixed)
                  TextFormField(
                    controller: _cashbackAmountCtrl,
                    decoration: const InputDecoration(labelText: 'Cashback ₹'),
                    keyboardType: TextInputType.number,
                  ),
                if (_cashbackKind == CashbackKind.percentage)
                  TextFormField(
                    controller: _cashbackPctCtrl,
                    decoration: const InputDecoration(labelText: 'Percentage %'),
                    keyboardType: TextInputType.number,
                  ),
                if (_cashbackKind == CashbackKind.rewardPoints)
                  TextFormField(
                    controller: _rewardPointsCtrl,
                    decoration: const InputDecoration(labelText: 'Reward points'),
                    keyboardType: TextInputType.number,
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends ConsumerState<TransactionDetailScreen> {
  Future<_TransactionDetailData>? _detailFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _detailFuture =
        ref.read(databaseProvider.future).then(_loadDetail);
    setState(() {});
  }

  static String _sourceTypeLabel(String key) {
    switch (key) {
      case 'BANK':
        return 'Bank account';
      case 'CREDIT_CARD':
        return 'Credit card';
      case 'DEBIT_CARD':
        return 'Debit card';
      case 'WALLET':
        return 'Wallet';
      case 'CASH':
        return 'Cash';
      default:
        return key;
    }
  }

  static String _cashbackLabel(CashbackModel cb) {
    switch (cb.kind) {
      case CashbackKind.fixed:
        return Formatters.currency.format(cb.amount);
      case CashbackKind.percentage:
        return '${cb.percentage?.toStringAsFixed(1) ?? '0'}% '
            '(${Formatters.currency.format(cb.amount)})';
      case CashbackKind.rewardPoints:
        return '${cb.rewardPoints ?? 0} points';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TransactionDetailData>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!;
        final txn = data.transaction;
        if (txn == null) {
          return const Scaffold(body: Center(child: Text('Not found')));
        }

        final split = data.split;
        final contactsById = {for (final c in data.contacts) c.id: c};

        return Scaffold(
          appBar: AppBar(
            title: const Text('Transaction'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () =>
                    context.push('/transactions/${widget.transactionId}/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  final service =
                      await ref.read(transactionServiceProvider.future);
                  await service.delete(widget.transactionId);
                  ref.invalidate(transactionsProvider);
                  ref.invalidate(dashboardStatsProvider);
                  ref.invalidate(paymentSourcesProvider);
                  ref.invalidate(billSplitsProvider);
                  if (context.mounted) context.pop();
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                Formatters.currency.format(txn.amount),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: txn.type == TransactionType.income
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
              ),
              Text(Formatters.txnType(txn.type)),
              if (txn.isAutomated)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Chip(
                    label: Text('Automated (NACH)'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const Divider(height: 24),
              const _SectionTitle('Details'),
              _DetailRow('Description', txn.description),
              _DetailRow('Category', Formatters.categoryLabel(txn.category)),
              _DetailRow('Date', Formatters.dateTime.format(txn.timestamp)),
              if (txn.type == TransactionType.expense &&
                  txn.cashbackReceived > 0) ...[
                _DetailRow(
                  'Net expense',
                  Formatters.currency.format(txn.netExpenseAmount),
                ),
              ],
              const SizedBox(height: 12),
              const _SectionTitle('Payment'),
              if (txn.type == TransactionType.income) ...[
                _DetailRow(
                  'Credited to',
                  data.source?.name ?? txn.paymentSourceId,
                ),
                if (data.source != null)
                  _DetailRow(
                    'Account type',
                    _sourceTypeLabel(data.source!.sourceTypeKey),
                  ),
              ] else ...[
                if (data.app != null)
                  _DetailRow('Payment app', data.app!.name)
                else
                  const _DetailRow('Payment app', 'None'),
                if (data.method != null)
                  _DetailRow('Payment method', data.method!.name),
                _DetailRow(
                  'Payment source',
                  data.source?.name ?? txn.paymentSourceId,
                ),
                if (data.source != null) ...[
                  _DetailRow(
                    'Source type',
                    _sourceTypeLabel(data.source!.sourceTypeKey),
                  ),
                  if (data.source!.bankName?.isNotEmpty == true)
                    _DetailRow('Bank', data.source!.bankName!),
                ],
              ],
              if (data.cashbacks.isNotEmpty) ...[
                const SizedBox(height: 12),
                const _SectionTitle('Cashback / rewards'),
                ...data.cashbacks.map(
                  (cb) => _DetailRow(
                    cb.kind == CashbackKind.rewardPoints
                        ? 'Reward points'
                        : 'Cashback',
                    _cashbackLabel(cb),
                  ),
                ),
                if (txn.cashbackReceived > 0)
                  _DetailRow(
                    'Total cashback',
                    Formatters.currency.format(txn.cashbackReceived),
                  ),
              ] else if (txn.cashbackReceived > 0)
                _DetailRow(
                  'Cashback',
                  Formatters.currency.format(txn.cashbackReceived),
                ),
              if (txn.cashbackFromExpenseId != null)
                _DetailRow('From expense', txn.cashbackFromExpenseId!),
              if (txn.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                const _SectionTitle('Notes'),
                Text(txn.notes!),
              ],
              if (split != null) ...[
                const SizedBox(height: 16),
                const _SectionTitle('Bill split'),
                if (data.group != null)
                  _DetailRow('Group', data.group!.name),
                SplitMembersSection(
                  split: split,
                  expense: txn,
                  contactsById: contactsById,
                  settlements: data.settlements,
                  onChanged: _reload,
                ),
              ],
              if (txn.type == TransactionType.expense) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context
                      .push('/transactions/${widget.transactionId}/split'),
                  icon: Icon(split != null ? Icons.edit : Icons.group_add),
                  label: Text(
                    split != null ? 'Edit bill split' : 'Add bill split',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<_TransactionDetailData> _loadDetail(AppDatabase db) async {
    final txn = await db.getTransaction(widget.transactionId);
    if (txn == null) {
      return const _TransactionDetailData();
    }

    final source = await db.getPaymentSource(txn.paymentSourceId);
    final methods = await db.getPaymentMethods();
    final apps = await db.getPaymentApps();
    final method = txn.paymentMethodId == null
        ? null
        : methods.where((m) => m.id == txn.paymentMethodId).firstOrNull;
    final app = txn.paymentAppId == null
        ? null
        : apps.where((a) => a.id == txn.paymentAppId).firstOrNull;
    final split = await db.getBillSplitForTransaction(widget.transactionId);
    final contacts = await db.getContacts();
    final cashbacks = await db.getCashbacksForTransaction(widget.transactionId);
    List<SplitSettlementModel> settlements = [];
    if (split != null) {
      settlements = await db.getSplitSettlementsForBillSplit(split.id);
    }
    GroupModel? group;
    if (split?.groupId != null) {
      final groups = await db.getGroups();
      group = groups.where((g) => g.id == split!.groupId).firstOrNull;
    }

    return _TransactionDetailData(
      transaction: txn,
      source: source,
      method: method,
      app: app,
      split: split,
      group: group,
      contacts: contacts,
      cashbacks: cashbacks,
      settlements: settlements,
    );
  }
}

class _TransactionDetailData {
  const _TransactionDetailData({
    this.transaction,
    this.source,
    this.method,
    this.app,
    this.split,
    this.group,
    this.contacts = const [],
    this.cashbacks = const [],
    this.settlements = const [],
  });

  final TransactionModel? transaction;
  final PaymentSourceModel? source;
  final PaymentMethodModel? method;
  final PaymentAppModel? app;
  final BillSplitModel? split;
  final GroupModel? group;
  final List<ContactModel> contacts;
  final List<CashbackModel> cashbacks;
  final List<SplitSettlementModel> settlements;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
