library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seedpod/constants/theme.dart';
import 'package:seedpod/models/log_entry.dart';
import 'package:seedpod/providers/app_state.dart';
import 'package:seedpod/widgets/quick_log_sheet.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final state = context.read<AppState>();
      if (state.entriesState == LoadState.idle) {
        state.loadEntries();
      }
    }
  }

  void _openQuickLog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickLogSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: colorBg,
      appBar: AppBar(title: const Text('Timeline')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openQuickLog,
        backgroundColor: colorPrimary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().loadEntries(),
        child: state.entriesState == LoadState.loading
            ? const Center(child: CircularProgressIndicator())
            : state.entries.isEmpty
                ? _EmptyState(onLog: _openQuickLog)
                : _TimelineList(entries: state.entries),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onLog;
  const _EmptyState({required this.onLog});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timeline, size: 56, color: colorSecondary),
          const SizedBox(height: 16),
          Text(
            'No entries yet',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Start logging your baby\'s activities.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onLog,
            icon: const Icon(Icons.add),
            label: const Text('Add First Entry'),
          ),
        ],
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  final List<LogEntry> entries;
  const _TimelineList({required this.entries});

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate(entries);
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: dates.length,
      itemBuilder: (ctx, i) {
        final date = dates[i];
        final dayEntries = grouped[date]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(date: date),
            for (int j = 0; j < dayEntries.length; j++)
              _TimelineItem(
                entry: dayEntries[j],
                isLast: j == dayEntries.length - 1,
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Map<String, List<LogEntry>> _groupByDate(List<LogEntry> entries) {
    final map = <String, List<LogEntry>>{};
    for (final e in entries) {
      final key =
          '${e.timestamp.year}-${e.timestamp.month.toString().padLeft(2, '0')}-${e.timestamp.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }
}

class _DateHeader extends StatelessWidget {
  final String date;
  const _DateHeader({required this.date});

  String _formatDate(String dateStr) {
    final d = DateTime.parse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final parsed = DateTime(d.year, d.month, d.day);
    if (parsed == today) return 'Today';
    if (parsed == yesterday) return 'Yesterday';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        _formatDate(date),
        style: const TextStyle(
          color: colorSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final LogEntry entry;
  final bool isLast;
  const _TimelineItem({required this.entry, required this.isLast});

  static const Map<LogType, IconData> _icons = {
    LogType.growth: Icons.straighten,
    LogType.sleep: Icons.bedtime,
    LogType.feeding: Icons.local_cafe,
    LogType.milestone: Icons.star,
    LogType.health: Icons.favorite,
    LogType.photo: Icons.photo_camera,
    LogType.environment: Icons.wb_sunny,
    LogType.note: Icons.edit_note,
  };

  static const Map<LogType, Color> _colors = {
    LogType.growth: Color(0xFF4A7C59),
    LogType.sleep: Color(0xFF7B68EE),
    LogType.feeding: Color(0xFFE8A87C),
    LogType.milestone: Color(0xFFFFD700),
    LogType.health: Color(0xFFFF6B6B),
    LogType.photo: Color(0xFF4ECDC4),
    LogType.environment: Color(0xFF45B7D1),
    LogType.note: Color(0xFF6B7280),
  };

  @override
  Widget build(BuildContext context) {
    final hour = entry.timestamp.hour.toString().padLeft(2, '0');
    final min = entry.timestamp.minute.toString().padLeft(2, '0');
    final color = _colors[entry.type] ?? colorPrimary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Icon(
                    _icons[entry.type] ?? Icons.circle,
                    color: color,
                    size: 16,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: colorDivider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showDetail(context),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorCard,
                  border: Border.all(color: colorDivider),
                  borderRadius: BorderRadius.circular(radiusMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.type.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$hour:$min',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        IconButton(
                          onPressed: () => _openEditor(context),
                          tooltip: 'Edit log',
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          color: colorPrimary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _buildSummary(entry),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (entry.note != null && entry.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.note!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickLogSheet(entry: entry),
    );
  }

  String _buildSummary(LogEntry e) {
    switch (e.type) {
      case LogType.growth:
        final parts = <String>[];
        final w = e.data['weight_kg']?.toString() ?? '';
        final h = e.data['height_cm']?.toString() ?? '';
        if (w.isNotEmpty) parts.add('${w}kg');
        if (h.isNotEmpty) parts.add('${h}cm');
        return parts.isEmpty ? 'Growth recorded' : parts.join(' · ');
      case LogType.sleep:
        final start = e.data['start'];
        final end = e.data['end'];
        if (start != null && end != null) {
          final s = DateTime.parse(start.toString());
          final en = DateTime.parse(end.toString());
          final dur = en.difference(s);
          return '${dur.inHours}h ${dur.inMinutes % 60}m sleep';
        }
        return 'Sleep logged';
      case LogType.feeding:
        final t = e.data['type'] ?? 'Feeding';
        final amt = e.data['amount_ml'];
        if (amt != null && amt.toString().isNotEmpty) return '$t · ${amt}ml';
        return '$t feeding';
      case LogType.milestone:
        return e.data['title']?.toString() ?? 'Milestone';
      default:
        return e.data['title']?.toString() ?? e.type.label;
    }
  }

  void _showDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.type.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final kv in entry.data.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${_prettify(kv.key)}: ${kv.value}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _prettify(String key) => key.replaceAll('_', ' ').replaceFirstMapped(
        RegExp(r'^.'),
        (m) => m.group(0)!.toUpperCase(),
      );
}
