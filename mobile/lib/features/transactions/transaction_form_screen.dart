import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/data/database.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/cashback_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(paymentSourcesProvider);
    final appsAsync = ref.watch(paymentAppsProvider);
    final methodsAsync = ref.watch(paymentMethodsProvider);

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
                  onChanged: (v) => setState(() => _appId = v),
                ),
              ),
              const SizedBox(height: 12),
              methodsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text('$e'),
                data: (methods) => DropdownButtonFormField<String?>(
                  value: _methodId,
                  decoration: const InputDecoration(labelText: 'Payment method'),
                  items: methods
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _methodId = v),
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
              data: (sources) {
                final filtered = _type == TransactionType.income
                    ? sources
                        .where((s) => s.sourceTypeKey != 'DEBIT_CARD')
                        .toList()
                    : sources;
                return DropdownButtonFormField<String?>(
                  value: _sourceId,
                  decoration: InputDecoration(
                    labelText: _type == TransactionType.income
                        ? 'Credited to'
                        : 'Payment source',
                  ),
                  items: filtered
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.name} (${Formatters.currency.format(s.balance)})'),
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

class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<TransactionModel?>(
      future: ref.read(databaseProvider.future).then(
            (db) => db.getTransaction(transactionId),
          ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final txn = snapshot.data;
        if (txn == null) {
          return const Scaffold(body: Center(child: Text('Not found')));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Transaction'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () =>
                    context.push('/transactions/$transactionId/edit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  final service =
                      await ref.read(transactionServiceProvider.future);
                  await service.delete(transactionId);
                  ref.invalidate(transactionsProvider);
                  ref.invalidate(dashboardStatsProvider);
                  ref.invalidate(paymentSourcesProvider);
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
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(Formatters.txnType(txn.type)),
              const Divider(),
              _DetailRow('Description', txn.description),
              _DetailRow('Category', Formatters.categoryLabel(txn.category)),
              _DetailRow('Date', Formatters.dateTime.format(txn.timestamp)),
              if (txn.cashbackReceived > 0)
                _DetailRow(
                  'Cashback',
                  Formatters.currency.format(txn.cashbackReceived),
                ),
              if (txn.notes?.isNotEmpty == true)
                _DetailRow('Notes', txn.notes!),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    context.push('/transactions/$transactionId/split'),
                icon: const Icon(Icons.group_add),
                label: const Text('Add bill split'),
              ),
            ],
          ),
        );
      },
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
