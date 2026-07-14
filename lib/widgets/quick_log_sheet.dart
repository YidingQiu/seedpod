library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:seedpod/constants/theme.dart';
import 'package:seedpod/models/log_entry.dart';
import 'package:seedpod/providers/app_state.dart';

class QuickLogSheet extends StatefulWidget {
  const QuickLogSheet({super.key});

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  LogType? _selectedType;
  bool _isSaving = false;

  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  // Growth fields
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  // Sleep fields
  DateTime? _sleepStart;
  DateTime? _sleepEnd;

  // Feeding fields
  String _feedingType = 'Breast';
  final _feedingAmountController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _feedingAmountController.dispose();
    super.dispose();
  }

  static const List<_LogTypeOption> _typeOptions = [
    _LogTypeOption(LogType.growth, Icons.straighten, 'Growth'),
    _LogTypeOption(LogType.sleep, Icons.bedtime, 'Sleep'),
    _LogTypeOption(LogType.feeding, Icons.local_cafe, 'Feeding'),
    _LogTypeOption(LogType.milestone, Icons.star, 'Milestone'),
    _LogTypeOption(LogType.health, Icons.favorite, 'Health'),
    _LogTypeOption(LogType.environment, Icons.wb_sunny, 'Weather'),
    _LogTypeOption(LogType.note, Icons.edit_note, 'Note'),
  ];

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
      final entry = LogEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: _selectedType!,
        timestamp: DateTime.now(),
        data: data,
      );

      if (!mounted) return;
      final ok = await context.read<AppState>().addEntry(entry);

      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log saved to your POD'),
            backgroundColor: colorPrimary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save. Please try again.'),
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
      default:
        return {
          if (_titleController.text.trim().isNotEmpty)
            'title': _titleController.text.trim(),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLarge)),
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
                      'Quick Log',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    _buildTypeGrid(),
                    if (_selectedType != null) ...[
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
                              : Text('Save ${_selectedType!.label}'),
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
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        for (final opt in _typeOptions)
          _TypeTile(
            option: opt,
            selected: _selectedType == opt.type,
            onTap: () => setState(() => _selectedType = opt.type),
          ),
      ],
    );
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'e.g. 5.2'),
            ),
            const SizedBox(height: 16),
            _label('Height (cm)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            const SizedBox(height: 16),
            _label('Amount (ml) — optional'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _feedingAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'e.g. 120'),
            ),
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

class _LogTypeOption {
  final LogType type;
  final IconData icon;
  final String label;

  const _LogTypeOption(this.type, this.icon, this.label);
}

class _TypeTile extends StatelessWidget {
  final _LogTypeOption option;
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
