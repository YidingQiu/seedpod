library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:seedpod/constants/theme.dart';
import 'package:seedpod/models/log_entry.dart';
import 'package:seedpod/models/log_type_option.dart';
import 'package:seedpod/providers/app_state.dart';

class QuickLogSheet extends StatefulWidget {
  final LogType? initialType;
  final LogEntry? entry;

  const QuickLogSheet({super.key, this.initialType, this.entry});

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  LogType? _selectedType;
  late DateTime _timestamp;
  bool _isSaving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _selectedType = entry?.type ?? widget.initialType;
    _timestamp = entry?.timestamp ?? DateTime.now();
    if (entry != null) _populateFromEntry(entry);
  }

  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  // Growth fields
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  // Sleep fields
  DateTime? _sleepStart;
  DateTime? _sleepEnd;

  // Nappy fields
  String _nappyType = 'Wet';

  // Medication fields
  final _medicationNameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();

  // Food fields
  final _foodNameCtrl = TextEditingController();
  String _foodReaction = 'None';

  // Teeth fields
  final _toothCtrl = TextEditingController();

  // Appointment fields
  String _appointmentType = 'GP';
  final _doctorCtrl = TextEditingController();

  // Feeding fields
  String _feedingType = 'Breast';
  String _breastSide = 'Left';
  final _feedingAmountController = TextEditingController();
  final _feedingDurationController = TextEditingController();

  void _populateFromEntry(LogEntry entry) {
    final data = entry.data;
    _noteController.text = data['note']?.toString() ?? '';
    _titleController.text =
        (entry.type == LogType.sleep_training ? data['method'] : data['title'])
                ?.toString() ??
            '';
    _weightController.text = data['weight_kg']?.toString() ?? '';
    _heightController.text = data['height_cm']?.toString() ?? '';
    _sleepStart = DateTime.tryParse(data['start']?.toString() ?? '');
    _sleepEnd = DateTime.tryParse(data['end']?.toString() ?? '');
    _nappyType = data['type']?.toString() ?? _nappyType;
    _medicationNameCtrl.text = data['name']?.toString() ?? '';
    _doseCtrl.text = data['dose']?.toString() ?? '';
    _foodNameCtrl.text = data['name']?.toString() ?? '';
    _foodReaction = data['reaction']?.toString() ?? _foodReaction;
    _toothCtrl.text = data['tooth']?.toString() ?? '';
    _appointmentType = data['type']?.toString() ?? _appointmentType;
    _doctorCtrl.text = data['doctor']?.toString() ?? '';
    _feedingType = data['type']?.toString() ?? _feedingType;
    _breastSide = data['side']?.toString() ?? _breastSide;
    _feedingAmountController.text = data['amount_ml']?.toString() ?? '';
    _feedingDurationController.text = data['duration_min']?.toString() ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _medicationNameCtrl.dispose();
    _doseCtrl.dispose();
    _foodNameCtrl.dispose();
    _toothCtrl.dispose();
    _doctorCtrl.dispose();
    _feedingAmountController.dispose();
    _feedingDurationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedType == null) return;

    setState(() => _isSaving = true);
    try {
      if (!await isUserLoggedIn()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);

      final data = _buildData();
      final original = widget.entry;
      final entry = LogEntry(
        id: original?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        babyId: original?.babyId ?? '',
        type: _selectedType!,
        timestamp: _isEditing ? _timestamp : DateTime.now(),
        data: data,
      );

      if (!mounted) return;
      final appState = context.read<AppState>();
      final ok = _isEditing
          ? await appState.updateEntry(entry)
          : await appState.addEntry(entry);

      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Log updated successfully.'
                  : 'Log saved to your POD',
            ),
            backgroundColor: colorPrimary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Failed to save changes. Please try again.'
                  : 'Failed to save. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on NotLoggedInException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to save logs'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, dynamic> _buildData() {
    switch (_selectedType!) {
      case LogType.growth:
        return {
          'weight_kg': _weightController.text.trim(),
          'height_cm': _heightController.text.trim(),
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        };
      case LogType.sleep:
        return {
          if (_sleepStart != null) 'start': _sleepStart!.toIso8601String(),
          if (_sleepEnd != null) 'end': _sleepEnd!.toIso8601String(),
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        };
      case LogType.feeding:
        return {
          'type': _feedingType,
          if (_feedingType == 'Breast') 'side': _breastSide,
          if (_feedingType == 'Breast' &&
              _feedingDurationController.text.trim().isNotEmpty)
            'duration_min': _feedingDurationController.text.trim(),
          if (_feedingAmountController.text.trim().isNotEmpty)
            'amount_ml': _feedingAmountController.text.trim(),
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        };
      case LogType.milestone:
      case LogType.health:
        return {
          'title': _titleController.text.trim(),
          'note': _noteController.text.trim(),
        };
      case LogType.nappy:
        return {
          'type': _nappyType,
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        };
      case LogType.medication:
        return {
          'name': _medicationNameCtrl.text.trim(),
          if (_doseCtrl.text.trim().isNotEmpty) 'dose': _doseCtrl.text.trim(),
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        };
      case LogType.food:
        return {
          'name': _foodNameCtrl.text.trim(),
          'reaction': _foodReaction,
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        };
      case LogType.teeth:
        return {
          if (_toothCtrl.text.trim().isNotEmpty)
            'tooth': _toothCtrl.text.trim(),
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        };
      case LogType.memory:
        return {
          if (_titleController.text.trim().isNotEmpty)
            'title': _titleController.text.trim(),
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        };
      case LogType.appointment:
        return {
          'type': _appointmentType,
          if (_doctorCtrl.text.trim().isNotEmpty)
            'doctor': _doctorCtrl.text.trim(),
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        };
      case LogType.sleep_training:
        return {
          if (_titleController.text.trim().isNotEmpty)
            'method': _titleController.text.trim(),
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        };
      default:
        return {
          if (_titleController.text.trim().isNotEmpty)
            'title': _titleController.text.trim(),
          if (_noteController.text.trim().isNotEmpty)
            'note': _noteController.text.trim(),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: colorBg,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(radiusLarge)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      _isEditing
                          ? 'Edit ${_selectedType!.label} Log'
                          : 'Quick Log',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    if (!_isEditing) _buildTypeGrid(),
                    if (_selectedType != null) ...[
                      if (_isEditing) ...[
                        _buildTimestampField(),
                      ],
                      const SizedBox(height: 24),
                      _buildForm(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isEditing
                                      ? 'Save Changes'
                                      : 'Save ${_selectedType!.label}',
                                ),
                        ),
                      ),
                    ],
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

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: colorDivider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTypeGrid() {
    final prefs = context.read<AppState>().modulePrefs;
    final visible = widget.initialType != null
        ? logTypeOptions.where((o) => o.type == widget.initialType).toList()
        : logTypeOptions.where((o) => prefs.isEnabled(o.moduleId)).toList();
    return GridView.count(
      crossAxisCount: 4,
      childAspectRatio: 1.0,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        for (final opt in visible)
          _TypeTile(
            option: opt,
            selected: _selectedType == opt.type,
            onTap: () => setState(() => _selectedType = opt.type),
          ),
      ],
    );
  }

  Widget _buildTimestampField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Log date and time'),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickTimestamp,
          borderRadius: BorderRadius.circular(radiusMedium),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorCard,
              border: Border.all(color: colorDivider),
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, color: colorSecondary, size: 20),
                const SizedBox(width: 12),
                Text(
                  '${_timestamp.day}/${_timestamp.month}/${_timestamp.year} '
                  '${_timestamp.hour.toString().padLeft(2, '0')}:'
                  '${_timestamp.minute.toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTimestamp() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
    );
    if (time == null || !mounted) return;
    setState(() {
      _timestamp = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Widget _buildForm() {
    switch (_selectedType!) {
      case LogType.growth:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Weight (kg)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'e.g. 5.2'),
            ),
            const SizedBox(height: 16),
            _label('Height (cm)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _heightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'e.g. 58.5'),
            ),
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
      case LogType.sleep:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Sleep start'),
            const SizedBox(height: 8),
            _timePickerTile(
              'Start time',
              _sleepStart,
              (t) => setState(() => _sleepStart = t),
            ),
            const SizedBox(height: 16),
            _label('Wake up'),
            const SizedBox(height: 8),
            _timePickerTile(
              'End time',
              _sleepEnd,
              (t) => setState(() => _sleepEnd = t),
            ),
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
      case LogType.feeding:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Feeding type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in ['Breast', 'Bottle', 'Formula', 'Solids'])
                  ChoiceChip(
                    label: Text(t),
                    selected: _feedingType == t,
                    selectedColor: colorPrimary.withOpacity(0.15),
                    onSelected: (s) {
                      if (s) setState(() => _feedingType = t);
                    },
                  ),
              ],
            ),
            if (_feedingType == 'Breast') ...[
              const SizedBox(height: 16),
              _label('Which side?'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final side in ['Left', 'Right'])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: side == 'Left' ? 8 : 0,
                        ),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _breastSide = side),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _breastSide == side
                                ? colorPrimary.withOpacity(0.1)
                                : null,
                            side: BorderSide(
                              color: _breastSide == side
                                  ? colorPrimary
                                  : colorDivider,
                              width: _breastSide == side ? 2 : 1,
                            ),
                            foregroundColor: _breastSide == side
                                ? colorPrimary
                                : colorSecondary,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                side == 'Left'
                                    ? Icons.arrow_back
                                    : Icons.arrow_forward,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(side),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _label('Duration (minutes)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _feedingDurationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'e.g. 15'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              _label('Amount (ml) — optional'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _feedingAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'e.g. 120'),
              ),
            ],
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
      case LogType.milestone:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Milestone'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'e.g. First smile, first steps...',
              ),
            ),
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
      case LogType.nappy:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Nappy type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in ['Wet', 'Dirty', 'Both', 'Dry'])
                  ChoiceChip(
                    label: Text(t),
                    selected: _nappyType == t,
                    selectedColor: colorPrimary.withOpacity(0.15),
                    onSelected: (s) {
                      if (s) setState(() => _nappyType = t);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
      case LogType.medication:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Medication name'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _medicationNameCtrl,
              decoration:
                  const InputDecoration(hintText: 'e.g. Panadol, Vitamin D'),
            ),
            const SizedBox(height: 16),
            _label('Dose (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _doseCtrl,
              decoration: const InputDecoration(hintText: 'e.g. 2.5 ml'),
            ),
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
      case LogType.food:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Food introduced'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _foodNameCtrl,
              decoration:
                  const InputDecoration(hintText: 'e.g. Pureed pumpkin'),
            ),
            const SizedBox(height: 16),
            _label('Reaction'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final r in ['None', 'Mild', 'Severe'])
                  ChoiceChip(
                    label: Text(r),
                    selected: _foodReaction == r,
                    selectedColor: r == 'Severe'
                        ? Colors.red.withOpacity(0.2)
                        : r == 'Mild'
                            ? Colors.orange.withOpacity(0.2)
                            : colorPrimary.withOpacity(0.15),
                    onSelected: (s) {
                      if (s) setState(() => _foodReaction = r);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
      case LogType.teeth:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Which tooth?'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _toothCtrl,
              decoration:
                  const InputDecoration(hintText: 'e.g. Bottom front left'),
            ),
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
      case LogType.memory:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Title'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'e.g. First laugh'),
            ),
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
      case LogType.appointment:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Appointment type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final t in [
                  'GP',
                  'Paediatrician',
                  'Specialist',
                  'Dentist',
                  'Emergency'
                ])
                  ChoiceChip(
                    label: Text(t),
                    selected: _appointmentType == t,
                    selectedColor: colorPrimary.withOpacity(0.15),
                    onSelected: (s) {
                      if (s) setState(() => _appointmentType = t);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _label('Doctor / clinic (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _doctorCtrl,
              decoration:
                  const InputDecoration(hintText: 'e.g. Dr. Smith, Calvary'),
            ),
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
      case LogType.health:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Symptom / condition'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                  hintText: 'e.g. Fever 38.5°C, runny nose'),
            ),
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
      case LogType.sleep_training:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Method'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                  hintText: 'e.g. Ferber, extinction, chair'),
            ),
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Title (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'Add a title'),
            ),
            const SizedBox(height: 16),
            _noteField(),
          ],
        );
    }
  }

  Widget _label(String text) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _noteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Notes (optional)'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _noteController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Add any notes...'),
        ),
      ],
    );
  }

  Widget _timePickerTile(
    String hint,
    DateTime? value,
    ValueChanged<DateTime> onPicked,
  ) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value ?? now),
        );
        if (t != null) {
          onPicked(DateTime(now.year, now.month, now.day, t.hour, t.minute));
        }
      },
      borderRadius: BorderRadius.circular(radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorCard,
          border: Border.all(color: colorDivider),
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: colorSecondary, size: 20),
            const SizedBox(width: 12),
            Text(
              value == null
                  ? hint
                  : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: value == null ? colorSecondary : colorText,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final LogTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? colorPrimary : colorCard,
          border: Border.all(
            color: selected ? colorPrimary : colorDivider,
          ),
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              option.icon,
              color: selected ? Colors.white : colorSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              option.label,
              style: TextStyle(
                color: selected ? Colors.white : colorText,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
