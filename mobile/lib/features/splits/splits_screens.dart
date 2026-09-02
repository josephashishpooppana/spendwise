import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/split_service.dart';
import 'package:uuid/uuid.dart';

class SplitsHubScreen extends ConsumerWidget {
  const SplitsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitsAsync = ref.watch(billSplitsProvider);

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
                    return ListTile(
                      leading: Icon(
                        split.isSettled ? Icons.check_circle : Icons.group,
                      ),
                      title: Text('Split on txn ${split.transactionId.substring(0, 8)}…'),
                      subtitle: Text(
                        '${split.splitType.name} · ${split.splitDetails.length} people',
                      ),
                      trailing: Text(
                        split.isSettled ? 'Settled' : 'Open',
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
        data: (contacts) => ListView.builder(
          itemCount: contacts.length,
          itemBuilder: (context, i) {
            final c = contacts[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(c.name),
              subtitle: Text(c.phoneNumber.isNotEmpty ? c.phoneNumber : c.upiId),
            );
          },
        ),
      ),
    );
  }
}

class ContactFormScreen extends ConsumerStatefulWidget {
  const ContactFormScreen({super.key});

  @override
  ConsumerState<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends ConsumerState<ContactFormScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  Future<void> _save() async {
    final db = await ref.read(databaseProvider.future);
    await db.upsertContact(
      ContactModel(
        id: const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        upiId: _upiCtrl.text.trim(),
      ),
    );
    ref.invalidate(contactsProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New contact'),
        actions: [IconButton(onPressed: _save, icon: const Icon(Icons.check))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          TextField(
            controller: _upiCtrl,
            decoration: const InputDecoration(labelText: 'UPI ID'),
          ),
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
            onPressed: () => _showCreateGroup(context, ref),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (groups) {
          final contacts = contactsAsync.valueOrNull ?? [];
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final g = groups[i];
              final names = g.memberIds
                  .map((id) => contacts.where((c) => c.id == id).firstOrNull?.name ?? id)
                  .join(', ');
              return ListTile(
                title: Text(g.name),
                subtitle: Text(names),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateGroup(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final contacts = await ref.read(contactsProvider.future);
    final selected = <String>{};

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New group'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Group name'),
                ),
                const SizedBox(height: 8),
                ...contacts.map(
                  (c) => CheckboxListTile(
                    title: Text(c.name),
                    value: selected.contains(c.id),
                    onChanged: (v) {
                      setLocal(() {
                        if (v == true) {
                          selected.add(c.id);
                        } else {
                          selected.remove(c.id);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final db = await ref.read(databaseProvider.future);
                await db.upsertGroup(
                  GroupModel(
                    id: const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    memberIds: selected.toList(),
                  ),
                );
                ref.invalidate(groupsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddSplitScreen extends ConsumerStatefulWidget {
  const AddSplitScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<AddSplitScreen> createState() => _AddSplitScreenState();
}

class _AddSplitScreenState extends ConsumerState<AddSplitScreen> {
  SplitType _splitType = SplitType.equal;
  final Map<String, double> _customAmounts = {};
  final Set<String> _selectedContacts = {};
  String? _groupId;

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsProvider);
    final splitService = SplitService();

    return Scaffold(
      appBar: AppBar(title: const Text('Add split')),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (contacts) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<SplitType>(
                segments: const [
                  ButtonSegment(value: SplitType.equal, label: Text('Equal')),
                  ButtonSegment(value: SplitType.custom, label: Text('Custom')),
                ],
                selected: {_splitType},
                onSelectionChanged: (s) =>
                    setState(() => _splitType = s.first),
              ),
              const SizedBox(height: 16),
              ...contacts.map((c) {
                return _splitType == SplitType.equal
                    ? CheckboxListTile(
                        title: Text(c.name),
                        value: _selectedContacts.contains(c.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedContacts.add(c.id);
                            } else {
                              _selectedContacts.remove(c.id);
                            }
                          });
                        },
                      )
                    : ListTile(
                        title: Text(c.name),
                        trailing: SizedBox(
                          width: 80,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '₹'),
                            onChanged: (v) {
                              _customAmounts[c.id] =
                                  double.tryParse(v) ?? 0;
                            },
                          ),
                        ),
                      );
              }),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final db = await ref.read(databaseProvider.future);
                  final txn = await db.getTransaction(widget.transactionId);
                  if (txn == null) return;

                  final split = _splitType == SplitType.equal
                      ? splitService.createEqualSplit(
                          id: const Uuid().v4(),
                          transactionId: widget.transactionId,
                          totalAmount: txn.amount,
                          contactIds: _selectedContacts.toList(),
                          groupId: _groupId,
                        )
                      : splitService.createCustomSplit(
                          id: const Uuid().v4(),
                          transactionId: widget.transactionId,
                          amounts: _customAmounts,
                          groupId: _groupId,
                        );

                  await db.upsertBillSplit(split);
                  ref.invalidate(billSplitsProvider);
                  if (context.mounted) context.pop();
                },
                child: const Text('Save split'),
              ),
            ],
          );
        },
      ),
    );
  }
}
