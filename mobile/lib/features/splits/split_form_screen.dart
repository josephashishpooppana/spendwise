import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spendwise_mobile/core/providers.dart';
import 'package:spendwise_mobile/core/theme.dart';
import 'package:spendwise_mobile/data/models/models.dart';
import 'package:spendwise_mobile/domain/services/split_service.dart';
import 'package:uuid/uuid.dart';

class SplitFormScreen extends ConsumerStatefulWidget {
  const SplitFormScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<SplitFormScreen> createState() => _SplitFormScreenState();
}

class _SplitFormScreenState extends ConsumerState<SplitFormScreen> {
  final _splitService = SplitService();
  final _customControllers = <String, TextEditingController>{};

  SplitType _splitType = SplitType.equal;
  String? _groupId;
  final Set<String> _selectedMemberIds = {};
  String? _existingSplitId;
  double _totalAmount = 0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _customControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final db = await ref.read(databaseProvider.future);
    final txn = await db.getTransaction(widget.transactionId);
    final split = await db.getBillSplitForTransaction(widget.transactionId);
    if (!mounted) return;

    if (txn == null) {
      setState(() => _loading = false);
      return;
    }

    _totalAmount = txn.amount;
    if (split != null) {
      _existingSplitId = split.id;
      _splitType = split.splitType;
      _groupId = split.groupId;
      _selectedMemberIds
        ..clear()
        ..addAll(split.splitDetails.keys);

      if (split.splitType == SplitType.custom) {
        final contactIds = split.splitDetails.keys.toList();
        final participants = [SplitService.selfParticipantId, ...contactIds];
        final autoId =
            participants.length >= 2 ? participants.last : null;
        final myAmount = split.myShare ??
            (_totalAmount -
                split.splitDetails.values.fold(0.0, (a, b) => a + b));

        if (autoId != SplitService.selfParticipantId) {
          _ensureCustomController(SplitService.selfParticipantId);
          _customControllers[SplitService.selfParticipantId]?.text =
              myAmount.toStringAsFixed(2);
        }
        for (final id in contactIds) {
          if (id == autoId) continue;
          _ensureCustomController(id);
          _customControllers[id]?.text =
              split.splitDetails[id]!.toStringAsFixed(2);
        }
      }
    }

    setState(() {
      _loading = false;
    });
  }

  void _ensureCustomController(String id) {
    _customControllers.putIfAbsent(id, TextEditingController.new);
  }

  List<String> _participantIdsFrom(List<ContactModel> groupMembers) => [
        SplitService.selfParticipantId,
        ...groupMembers
            .where((c) => _selectedMemberIds.contains(c.id))
            .map((c) => c.id),
      ];

  String? _autoParticipantIdFor(List<String> participantIds) {
    if (participantIds.length < 2) return null;
    return participantIds.last;
  }

  Map<String, double> _enteredCustomAmountsFor(
    List<String> participantIds,
    String? autoId,
  ) {
    final amounts = <String, double>{};
    for (final id in participantIds) {
      if (id == autoId) continue;
      amounts[id] = double.tryParse(_customControllers[id]?.text ?? '') ?? 0;
    }
    return amounts;
  }

  Map<String, double> _previewFor(List<String> participantIds) {
    if (participantIds.length < 2) return {};
    if (_splitType == SplitType.equal) {
      final share = SplitService.equalShare(
        _totalAmount,
        participantIds.length,
      );
      return {for (final id in participantIds) id: share};
    }
    final autoId = _autoParticipantIdFor(participantIds);
    return SplitService.customAmountsWithRemainder(
      totalAmount: _totalAmount,
      participantIds: participantIds,
      enteredAmounts: _enteredCustomAmountsFor(participantIds, autoId),
    );
  }

  bool _canSaveFor(
    List<String> participantIds,
    Map<String, double> preview,
  ) {
    if (_groupId == null || _selectedMemberIds.isEmpty) return false;
    if (_splitType == SplitType.equal) return participantIds.length >= 2;
    if (preview.isEmpty) return false;
    final autoId = _autoParticipantIdFor(participantIds);
    if (autoId != null && (preview[autoId] ?? 0) < -0.001) return false;
    return SplitService.customTotalsMatch(
      totalAmount: _totalAmount,
      amounts: preview,
    );
  }

  void _onGroupChanged(String? groupId) {
    setState(() {
      _groupId = groupId;
      _selectedMemberIds.clear();
      for (final c in _customControllers.values) {
        c.dispose();
      }
      _customControllers.clear();
    });
  }

  void _onMemberToggle(String contactId, bool selected) {
    setState(() {
      if (selected) {
        _selectedMemberIds.add(contactId);
      } else {
        _selectedMemberIds.remove(contactId);
        _customControllers.remove(contactId)?.dispose();
      }
      if (_splitType == SplitType.custom) {
        _ensureCustomController(SplitService.selfParticipantId);
      }
    });
  }

  void _onSplitTypeChanged(SplitType type) {
    setState(() {
      _splitType = type;
      if (type == SplitType.custom) {
        _ensureCustomController(SplitService.selfParticipantId);
      }
    });
  }

  Future<void> _save(List<ContactModel> groupMembers) async {
    final participantIds = _participantIdsFrom(groupMembers);
    final preview = _previewFor(participantIds);
    if (!_canSaveFor(participantIds, preview)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a group, at least one member, and ensure custom amounts equal the total.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final db = await ref.read(databaseProvider.future);
      final splitId = _existingSplitId ?? const Uuid().v4();
      final contactIds = groupMembers
          .where((c) => _selectedMemberIds.contains(c.id))
          .map((c) => c.id)
          .toList();
      final autoId = _autoParticipantIdFor(participantIds);

      final BillSplitModel split;
      if (_splitType == SplitType.equal) {
        split = _splitService.createEqualSplit(
          id: splitId,
          transactionId: widget.transactionId,
          totalAmount: _totalAmount,
          contactIds: contactIds,
          groupId: _groupId!,
        );
      } else {
        split = _splitService.createCustomSplit(
          id: splitId,
          transactionId: widget.transactionId,
          totalAmount: _totalAmount,
          contactIds: contactIds,
          enteredAmounts: _enteredCustomAmountsFor(participantIds, autoId),
          groupId: _groupId!,
        );
      }

      await db.upsertBillSplit(split);
      ref.invalidate(billSplitsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_existingSplitId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete split?'),
        content: const Text('Remove this bill split from the expense?'),
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

    final db = await ref.read(databaseProvider.future);
    await db.deleteBillSplit(_existingSplitId!);
    ref.invalidate(billSplitsProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final groupsAsync = ref.watch(groupsProvider);
    final contactsAsync = ref.watch(contactsProvider);
    final allContacts = contactsAsync.valueOrNull ?? [];
    final contactsById = {for (final c in allContacts) c.id: c};

    final selectedGroup = _groupId == null
        ? null
        : groupsAsync.valueOrNull?.where((g) => g.id == _groupId).firstOrNull;

    final groupMembers = selectedGroup == null
        ? <ContactModel>[]
        : selectedGroup.memberIds
            .map((id) => contactsById[id])
            .whereType<ContactModel>()
            .toList();

    final isEdit = _existingSplitId != null;
    final participantIds = _participantIdsFrom(groupMembers);
    final autoId = _autoParticipantIdFor(participantIds);
    final preview = _previewFor(participantIds);
    final canSave = _canSaveFor(participantIds, preview);
    final remaining =
        _splitType == SplitType.custom && autoId != null ? preview[autoId] ?? 0 : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit split' : 'Add split'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(onPressed: canSave ? () => _save(groupMembers) : null, icon: const Icon(Icons.check)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Expense total'),
              trailing: Text(
                Formatters.currency.format(_totalAmount),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<SplitType>(
            segments: const [
              ButtonSegment(value: SplitType.equal, label: Text('Equal')),
              ButtonSegment(value: SplitType.custom, label: Text('Custom')),
            ],
            selected: {_splitType},
            onSelectionChanged: (s) => _onSplitTypeChanged(s.first),
          ),
          const SizedBox(height: 16),
          groupsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (groups) {
              if (groups.isEmpty) {
                return const Text('Create a group first under Splits → Groups.');
              }
              return DropdownButtonFormField<String>(
                value: _groupId,
                decoration: const InputDecoration(
                  labelText: 'Group *',
                  helperText: 'One group per expense split',
                ),
                items: groups
                    .map(
                      (g) => DropdownMenuItem(value: g.id, child: Text(g.name)),
                    )
                    .toList(),
                onChanged: _onGroupChanged,
              );
            },
          ),
          if (_groupId != null) ...[
            const SizedBox(height: 16),
            Text('Members', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (groupMembers.isEmpty)
              const Text('This group has no members yet.')
            else
              ...groupMembers.map(
                (c) => CheckboxListTile(
                  title: Text(c.name),
                  subtitle: c.phoneNumber.isNotEmpty ? Text(c.phoneNumber) : null,
                  value: _selectedMemberIds.contains(c.id),
                  onChanged: (v) => _onMemberToggle(c.id, v == true),
                ),
              ),
          ],
          if (_selectedMemberIds.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Split preview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  if (_splitType == SplitType.equal)
                    ...participantIds.map(
                      (id) => ListTile(
                        title: Text(
                          _splitService.participantLabel(id, contactsById),
                        ),
                        trailing: Text(
                          Formatters.currency.format(preview[id] ?? 0),
                        ),
                      ),
                    )
                  else ...[
                    ...participantIds.map((id) {
                      final isAuto = id == autoId;
                      if (isAuto) {
                        return ListTile(
                          title: Text(
                            _splitService.participantLabel(id, contactsById),
                          ),
                          subtitle: const Text('Auto (remaining)'),
                          trailing: Text(
                            Formatters.currency.format(remaining ?? 0),
                            style: TextStyle(
                              color: (remaining ?? 0) < 0 ? Colors.red : null,
                            ),
                          ),
                        );
                      }
                      _ensureCustomController(id);
                      return ListTile(
                        title: Text(
                          _splitService.participantLabel(id, contactsById),
                        ),
                        trailing: SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _customControllers[id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              prefixText: '₹ ',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        canSave
                            ? 'Total matches ${Formatters.currency.format(_totalAmount)}'
                            : 'Enter amounts; the last person gets the remainder. Total must match the expense.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canSave && !_saving ? () => _save(groupMembers) : null,
            child: Text(isEdit ? 'Update split' : 'Save split'),
          ),
          if (isEdit) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'Delete split',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
