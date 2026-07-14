library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:seedpod/constants/theme.dart';
import 'package:seedpod/models/childcare_entry.dart';
import 'package:seedpod/providers/app_state.dart';

class ChildcareScreen extends StatefulWidget {
  const ChildcareScreen({super.key});

  @override
  State<ChildcareScreen> createState() => _ChildcareScreenState();
}

class _ChildcareScreenState extends State<ChildcareScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    if (state.childcareState == LoadState.idle) {
      state.loadChildcareEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final entries = state.childcareEntries;

    return Scaffold(
      backgroundColor: colorBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        backgroundColor: colorPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Centre'),
      ),
      body: state.childcareState == LoadState.loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Childcare & Schools',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track waitlists and enrolments. In Canberra, start your applications early — some centres have 2+ year waits.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _SummaryRow(entries: entries),
                  const SizedBox(height: 20),
                  if (entries.isEmpty)
                    _EmptyState(onAdd: () => _showAddSheet(context))
                  else
                    for (final e in entries)
                      _EntryCard(
                        entry: e,
                        onEdit: () => _showEditSheet(context, e),
                        onDelete: () => _confirmDelete(context, e),
                      ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChildcareFormSheet(
        onSave: (entry) async {
          if (!await isUserLoggedIn()) return;
          if (!context.mounted) return;
          await getKeyFromUserIfRequired(context, widget);
          if (!context.mounted) return;
          await context.read<AppState>().addChildcareEntry(entry);
        },
      ),
    );
  }

  void _showEditSheet(BuildContext context, ChildcareEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChildcareFormSheet(
        existing: entry,
        onSave: (updated) async {
          if (!await isUserLoggedIn()) return;
          if (!context.mounted) return;
          await getKeyFromUserIfRequired(context, widget);
          if (!context.mounted) return;
          await context.read<AppState>().updateChildcareEntry(updated);
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ChildcareEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove entry?'),
        content: Text('Remove "${entry.centerName}" from your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().deleteChildcareEntry(entry.id);
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final List<ChildcareEntry> entries;
  const _SummaryRow({required this.entries});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final e in entries) {
      counts[e.status] = (counts[e.status] ?? 0) + 1;
    }

    return Row(
      children: [
        _CountChip('${entries.length}', 'Total', colorSecondary),
        const SizedBox(width: 8),
        if ((counts['waitlisted'] ?? 0) > 0)
          _CountChip('${counts['waitlisted']}', 'Waitlisted', colorAccent),
        if ((counts['offered'] ?? 0) > 0) ...[
          const SizedBox(width: 8),
          _CountChip('${counts['offered']}', 'Offered', colorPrimary),
        ],
        if ((counts['enrolled'] ?? 0) > 0) ...[
          const SizedBox(width: 8),
          _CountChip('${counts['enrolled']}', 'Enrolled', colorPrimary),
        ],
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  const _CountChip(this.count, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorCard,
        border: Border.all(color: colorDivider),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        children: [
          const Icon(Icons.school_outlined, size: 40, color: colorSecondary),
          const SizedBox(height: 12),
          Text('No centres yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Add childcare centres and schools you have applied to or are interested in.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add First Centre'),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final ChildcareEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  static const _statusColors = {
    'applied': colorSecondary,
    'waitlisted': colorAccent,
    'offered': colorPrimary,
    'enrolled': colorPrimary,
    'declined': Colors.red,
  };

  static const _statusLabels = {
    'applied': 'Applied',
    'waitlisted': 'Waitlisted',
    'offered': 'Offered',
    'enrolled': 'Enrolled',
    'declined': 'Declined',
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[entry.status] ?? colorSecondary;
    final label = _statusLabels[entry.status] ?? entry.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colorCard,
        border: Border.all(color: colorDivider),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school_outlined, size: 18, color: colorPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.centerName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (entry.suburb != null)
                    _Detail(Icons.location_on_outlined, entry.suburb!),
                  if (entry.type != null)
                    _Detail(Icons.category_outlined, entry.type!),
                  _Detail(
                    Icons.calendar_today_outlined,
                    'Applied ${_fmtDate(entry.appliedDate)}',
                  ),
                  if (entry.desiredStartDate != null)
                    _Detail(
                      Icons.flag_outlined,
                      'Start ${_fmtDate(entry.desiredStartDate!)}',
                    ),
                  if (entry.dailyFeeAud != null)
                    _Detail(
                      Icons.attach_money,
                      '\$${entry.dailyFeeAud!.toStringAsFixed(0)}/day',
                    ),
                  if (entry.waitlistPosition != null)
                    _Detail(
                      Icons.format_list_numbered,
                      'Position #${entry.waitlistPosition}',
                    ),
                ],
              ),
              if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  entry.notes!,
                  style: const TextStyle(color: colorSecondary, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(foregroundColor: colorPrimary),
                  ),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(foregroundColor: colorSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Detail(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colorSecondary),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(color: colorSecondary, fontSize: 12)),
      ],
    );
  }
}

// ── Add / Edit form sheet ─────────────────────────────────────────────────────

class _ChildcareFormSheet extends StatefulWidget {
  final ChildcareEntry? existing;
  final Future<void> Function(ChildcareEntry) onSave;

  const _ChildcareFormSheet({this.existing, required this.onSave});

  @override
  State<_ChildcareFormSheet> createState() => _ChildcareFormSheetState();
}

class _ChildcareFormSheetState extends State<_ChildcareFormSheet> {
  final _nameCtrl = TextEditingController();
  final _suburbCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _posCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _status = 'applied';
  String? _type;
  DateTime _appliedDate = DateTime.now();
  DateTime? _desiredStartDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.centerName;
      _suburbCtrl.text = e.suburb ?? '';
      _feeCtrl.text = e.dailyFeeAud?.toStringAsFixed(0) ?? '';
      _posCtrl.text = e.waitlistPosition?.toString() ?? '';
      _notesCtrl.text = e.notes ?? '';
      _status = e.status;
      _type = e.type;
      _appliedDate = e.appliedDate;
      _desiredStartDate = e.desiredStartDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _suburbCtrl.dispose();
    _feeCtrl.dispose();
    _posCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final entry = ChildcareEntry(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      centerName: _nameCtrl.text.trim(),
      suburb: _suburbCtrl.text.trim().isEmpty ? null : _suburbCtrl.text.trim(),
      type: _type,
      appliedDate: _appliedDate,
      desiredStartDate: _desiredStartDate,
      status: _status,
      dailyFeeAud: double.tryParse(_feeCtrl.text),
      waitlistPosition: int.tryParse(_posCtrl.text),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    try {
      await widget.onSave(entry);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _appliedDate : (_desiredStartDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _appliedDate = picked;
        } else {
          _desiredStartDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: colorBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.existing == null ? 'Add Centre' : 'Edit Centre',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),

                    _label('Centre / School Name *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Canberra Early Learning Centre',
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Suburb'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _suburbCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. Braddon',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Type'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _type,
                                hint: const Text('Select'),
                                decoration: const InputDecoration(),
                                items: ChildcareEntry.typeOptions
                                    .map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t,
                                              style: const TextStyle(fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => _type = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _label('Status'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ChildcareEntry.statusOptions
                          .map((s) => ChoiceChip(
                                label: Text(
                                  s[0].toUpperCase() + s.substring(1),
                                ),
                                selected: _status == s,
                                selectedColor: colorPrimary.withOpacity(0.15),
                                onSelected: (_) => setState(() => _status = s),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _DateTile(
                            label: 'Date Applied',
                            date: _appliedDate,
                            onTap: () => _pickDate(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateTile(
                            label: 'Desired Start',
                            date: _desiredStartDate,
                            hint: 'Not set',
                            onTap: () => _pickDate(isStart: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Daily Fee (AUD)'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _feeCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 140',
                                  prefixText: '\$',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Waitlist Position'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _posCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 12',
                                  prefixText: '#',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _label('Notes (optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Contact name, phone number, impressions...',
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(widget.existing == null ? 'Save Centre' : 'Update Centre'),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14));
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final String? hint;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.date,
    this.hint,
    required this.onTap,
  });

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radiusMedium),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: colorCard,
              border: Border.all(color: colorDivider),
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: colorSecondary),
                const SizedBox(width: 8),
                Text(
                  date != null ? _fmt(date!) : (hint ?? ''),
                  style: TextStyle(
                    color: date != null ? colorText : colorSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
