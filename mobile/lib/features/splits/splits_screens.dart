import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/split_balance_helper.dart';
import 'package:uuid/uuid.dart';

class SplitsHubScreen extends ConsumerWidget {
  const SplitsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitsAsync = ref.watch(billSplitsProvider);
    final settlementsAsync = ref.watch(splitSettlementsProvider);
    final txnsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill splits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => context.push('/contacts/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/contacts'),
                    icon: const Icon(Icons.contacts),
                    label: const Text('Contacts'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/groups'),
                    icon: const Icon(Icons.group),
                    label: const Text('Groups'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: splitsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (splits) {
                final settlementsBySplit = <String, List<SplitSettlementModel>>{};
                for (final s in settlementsAsync.valueOrNull ?? []) {
                  settlementsBySplit
                      .putIfAbsent(s.billSplitId, () => [])
                      .add(s);
                }
                final txnsById = {
                  for (final t in txnsAsync.valueOrNull ?? []) t.id: t,
                };

                if (splits.isEmpty) {
                  return const Center(
                    child: Text(
                      'No splits yet.\nCreate an expense and add a split from transaction details.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: splits.length,
                  itemBuilder: (context, i) {
                    final split = splits[i];
                    final outstanding = SplitBalanceHelper.totalOutstanding(
                      split: split,
                      settlements:
                          settlementsBySplit[split.id] ?? const [],
                    );
                    final txn = txnsById[split.transactionId];
                    final title = txn?.description ??
                        'Split on txn ${split.transactionId.substring(0, 8)}…';

                    return ListTile(
                      leading: Icon(
                        outstanding < 0.01
                            ? Icons.check_circle
                            : Icons.pending_actions,
                        color: outstanding < 0.01
                            ? Colors.green
                            : Colors.orange,
                      ),
                      title: Text(title),
                      subtitle: Text(
                        outstanding > 0.009
                            ? 'To collect ${Formatters.currency.format(outstanding)} · '
                                '${split.splitDetails.length + 1} people'
                            : '${split.splitType.name} · ${split.splitDetails.length + 1} people',
                      ),
                      trailing: Text(
                        outstanding < 0.01 ? 'Settled' : 'Open',
                      ),
                      onTap: () => context.push(
                        txn != null
                            ? '/transactions/${split.transactionId}'
                            : '/transactions/${split.transactionId}/split',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/contacts/new'),
          ),
        ],
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (contacts) => contacts.isEmpty
            ? const Center(child: Text('No contacts yet.\nTap + to add one.'))
            : ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, i) {
                  final c = contacts[i];
                  final subtitle = [
                    if (c.phoneNumber.isNotEmpty) c.phoneNumber,
                    if (c.upiId.isNotEmpty) c.upiId,
                    if (c.email.isNotEmpty) c.email,
                  ].join(' · ');
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(c.name),
                    subtitle: subtitle.isEmpty ? null : Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/contacts/${c.id}'),
                  );
                },
              ),
      ),
    );
  }
}

class ContactFormScreen extends ConsumerStatefulWidget {
  const ContactFormScreen({super.key, this.contactId});

  final String? contactId;

  @override
  ConsumerState<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends ConsumerState<ContactFormScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();
  bool _loading = false;

  bool get _isEdit => widget.contactId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final db = await ref.read(databaseProvider.future);
    final contacts = await db.getContacts();
    final contact =
        contacts.where((c) => c.id == widget.contactId).firstOrNull;
    if (contact == null || !mounted) return;
    setState(() {
      _nameCtrl.text = contact.name;
      _phoneCtrl.text = contact.phoneNumber;
      _emailCtrl.text = contact.email;
      _upiCtrl.text = contact.upiId;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final db = await ref.read(databaseProvider.future);
      await db.upsertContact(
        ContactModel(
          id: widget.contactId ?? const Uuid().v4(),
          name: name,
          phoneNumber: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          upiId: _upiCtrl.text.trim(),
        ),
      );
      ref.invalidate(contactsProvider);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text('Remove ${_nameCtrl.text.trim()}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final db = await ref.read(databaseProvider.future);
      await db.deleteContact(widget.contactId!);
      ref.invalidate(contactsProvider);
      ref.invalidate(groupsProvider);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit contact' : 'New contact'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name *'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(labelText: 'Phone'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _upiCtrl,
            decoration: const InputDecoration(labelText: 'UPI ID'),
          ),
          if (_isEdit) ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'Delete contact',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/groups/new'),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (groups) {
          final contacts = contactsAsync.valueOrNull ?? [];
          if (groups.isEmpty) {
            return const Center(
              child: Text('No groups yet.\nTap + to create one.'),
            );
          }
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final g = groups[i];
              final names = g.memberIds
                  .map(
                    (id) =>
                        contacts.where((c) => c.id == id).firstOrNull?.name ??
                        id,
                  )
                  .join(', ');
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.group)),
                title: Text(g.name),
                subtitle: Text(
                  names.isEmpty
                      ? '${g.memberIds.length} member(s)'
                      : names,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/groups/${g.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({super.key, this.groupId});

  final String? groupId;

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final _nameCtrl = TextEditingController();
  final Set<String> _selectedMemberIds = {};
  bool _loading = false;

  bool get _isEdit => widget.groupId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final db = await ref.read(databaseProvider.future);
    final groups = await db.getGroups();
    final group = groups.where((g) => g.id == widget.groupId).firstOrNull;
    if (group == null || !mounted) return;
    setState(() {
      _nameCtrl.text = group.name;
      _selectedMemberIds
        ..clear()
        ..addAll(group.memberIds);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name is required')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final db = await ref.read(databaseProvider.future);
      await db.upsertGroup(
        GroupModel(
          id: widget.groupId ?? const Uuid().v4(),
          name: name,
          memberIds: _selectedMemberIds.toList(),
        ),
      );
      ref.invalidate(groupsProvider);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text('Remove ${_nameCtrl.text.trim()}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final db = await ref.read(databaseProvider.future);
      await db.deleteGroup(widget.groupId!);
      ref.invalidate(groupsProvider);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit group' : 'New group'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Group name *'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          Text('Members', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          contactsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (contacts) {
              if (contacts.isEmpty) {
                return const Text(
                  'Add contacts first, then select group members.',
                );
              }
              return Column(
                children: contacts.map((c) {
                  return CheckboxListTile(
                    title: Text(c.name),
                    subtitle: c.phoneNumber.isNotEmpty
                        ? Text(c.phoneNumber)
                        : null,
                    value: _selectedMemberIds.contains(c.id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedMemberIds.add(c.id);
                        } else {
                          _selectedMemberIds.remove(c.id);
                        }
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
          if (_isEdit) ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'Delete group',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
