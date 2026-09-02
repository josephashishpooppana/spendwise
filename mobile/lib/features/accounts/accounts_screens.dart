import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:uuid/uuid.dart';

class AccountsHubScreen extends ConsumerWidget {
  const AccountsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_balance),
            title: const Text('Payment sources'),
            subtitle: const Text('Banks, cards, wallets, cash'),
            onTap: () => context.push('/sources/list'),
          ),
          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text('Payment apps'),
            subtitle: const Text('Google Pay, PhonePe, etc.'),
            onTap: () => context.push('/apps'),
          ),
          ListTile(
            leading: const Icon(Icons.payment),
            title: const Text('Payment methods'),
            subtitle: const Text('UPI, cash, cards, etc.'),
            onTap: () => context.push('/methods'),
          ),
        ],
      ),
    );
  }
}

class PaymentSourcesScreen extends ConsumerWidget {
  const PaymentSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(paymentSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment sources'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/sources/new'),
          ),
        ],
      ),
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (sources) => ListView.builder(
          itemCount: sources.length,
          itemBuilder: (context, i) {
            final s = sources[i];
            return ListTile(
              leading: Icon(_iconForType(s.sourceTypeKey)),
              title: Text(s.name),
              subtitle: Text(s.sourceTypeKey),
              trailing: Text(Formatters.currency.format(s.balance)),
              onTap: () => context.push('/sources/${s.id}'),
            );
          },
        ),
      ),
    );
  }

  IconData _iconForType(String key) {
    switch (key) {
      case 'BANK':
        return Icons.account_balance;
      case 'CREDIT_CARD':
        return Icons.credit_card;
      case 'DEBIT_CARD':
        return Icons.credit_score;
      case 'WALLET':
        return Icons.wallet;
      case 'CASH':
        return Icons.payments;
      default:
        return Icons.account_balance_wallet;
    }
  }
}

class PaymentSourceFormScreen extends ConsumerStatefulWidget {
  const PaymentSourceFormScreen({super.key, this.sourceId});

  final String? sourceId;

  @override
  ConsumerState<PaymentSourceFormScreen> createState() =>
      _PaymentSourceFormScreenState();
}

class _PaymentSourceFormScreenState
    extends ConsumerState<PaymentSourceFormScreen> {
  final _nameCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController(text: '0');
  String _typeKey = 'BANK';
  String? _linkedBankId;
  bool _loading = false;

  static const _types = [
    'BANK',
    'CREDIT_CARD',
    'DEBIT_CARD',
    'WALLET',
    'CASH',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.sourceId != null) _load();
  }

  Future<void> _load() async {
    final db = await ref.read(databaseProvider.future);
    final s = await db.getPaymentSource(widget.sourceId!);
    if (s == null || !mounted) return;
    setState(() {
      _nameCtrl.text = s.name;
      _bankCtrl.text = s.bankName ?? '';
      _balanceCtrl.text = s.balance.toString();
      _typeKey = s.sourceTypeKey;
      _linkedBankId = s.linkedBankSourceId;
    });
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final db = await ref.read(databaseProvider.future);
    final id = widget.sourceId ?? const Uuid().v4();
    await db.upsertPaymentSource(
      PaymentSourceModel(
        id: id,
        name: _nameCtrl.text.trim(),
        bankName: _bankCtrl.text.trim().isEmpty ? null : _bankCtrl.text.trim(),
        sourceTypeKey: _typeKey,
        balance: double.tryParse(_balanceCtrl.text) ?? 0,
        linkedBankSourceId:
            _typeKey == 'DEBIT_CARD' ? _linkedBankId : null,
      ),
    );
    ref.invalidate(paymentSourcesProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final banksAsync = ref.watch(paymentSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sourceId == null ? 'New source' : 'Edit source'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bankCtrl,
            decoration: const InputDecoration(labelText: 'Bank name (optional)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _typeKey,
            decoration: const InputDecoration(labelText: 'Type'),
            items: _types
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _typeKey = v ?? _typeKey),
          ),
          if (_typeKey == 'DEBIT_CARD')
            banksAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => Text('$e'),
              data: (sources) {
                final banks =
                    sources.where((s) => s.sourceTypeKey == 'BANK').toList();
                return DropdownButtonFormField<String?>(
                  value: _linkedBankId,
                  decoration: const InputDecoration(
                    labelText: 'Linked bank account',
                  ),
                  items: banks
                      .map(
                        (b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _linkedBankId = v),
                );
              },
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _balanceCtrl,
            decoration: const InputDecoration(labelText: 'Opening balance'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }
}

class PaymentAppsScreen extends ConsumerWidget {
  const PaymentAppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(paymentAppsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment apps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/apps/new'),
          ),
        ],
      ),
      body: appsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (apps) => ListView.builder(
          itemCount: apps.length,
          itemBuilder: (context, i) {
            final app = apps[i];
            return ListTile(
              leading: const Icon(Icons.apps),
              title: Text(app.name),
              subtitle: Text('${app.supportedMethodIds.length} methods'),
              onTap: () => context.push('/apps/${app.id}'),
            );
          },
        ),
      ),
    );
  }
}

class PaymentAppFormScreen extends ConsumerStatefulWidget {
  const PaymentAppFormScreen({super.key, this.appId});

  final String? appId;

  @override
  ConsumerState<PaymentAppFormScreen> createState() =>
      _PaymentAppFormScreenState();
}

class _PaymentAppFormScreenState extends ConsumerState<PaymentAppFormScreen> {
  final _nameCtrl = TextEditingController();
  final Set<String> _selectedMethodIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.appId != null) _load();
  }

  Future<void> _load() async {
    final db = await ref.read(databaseProvider.future);
    final apps = await db.getPaymentApps(all: true);
    final app = apps.where((a) => a.id == widget.appId).firstOrNull;
    if (app == null || !mounted) return;
    setState(() {
      _nameCtrl.text = app.name;
      _selectedMethodIds.addAll(app.supportedMethodIds);
    });
  }

  Future<void> _save() async {
    final db = await ref.read(databaseProvider.future);
    final id = widget.appId ?? const Uuid().v4();
    await db.upsertPaymentApp(
      PaymentAppModel(
        id: id,
        name: _nameCtrl.text.trim(),
        supportedMethodIds: _selectedMethodIds.toList(),
      ),
    );
    ref.invalidate(paymentAppsProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appId == null ? 'New app' : 'Edit app'),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.check))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'App name',
              hintText: 'Google Pay',
            ),
          ),
          const SizedBox(height: 16),
          Text('Supported methods', style: Theme.of(context).textTheme.titleMedium),
          methodsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (methods) => Column(
              children: methods.map((m) {
                return CheckboxListTile(
                  title: Text(m.name),
                  value: _selectedMethodIds.contains(m.id),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedMethodIds.add(m.id);
                      } else {
                        _selectedMethodIds.remove(m.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment methods')),
      body: methodsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (methods) => ListView.builder(
          itemCount: methods.length,
          itemBuilder: (context, i) {
            final m = methods[i];
            return ListTile(
              title: Text(m.name),
              subtitle: Text(
                m.isBuiltIn ? 'Built-in · ${m.key}' : 'Custom',
              ),
              trailing: m.isBuiltIn
                  ? const Icon(Icons.lock_outline, size: 18)
                  : null,
            );
          },
        ),
      ),
    );
  }
}
