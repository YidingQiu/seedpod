library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solidpod/solidpod.dart';

import 'package:seedpod/constants/theme.dart';
import 'package:seedpod/models/baby_profile.dart';
import 'package:seedpod/models/log_entry.dart';
import 'package:seedpod/models/module_prefs.dart';
import 'package:seedpod/models/log_type_option.dart';
import 'package:seedpod/models/vaccine_reminder.dart';
import 'package:seedpod/providers/app_state.dart';
import 'package:seedpod/screens/health_screen.dart';
import 'package:seedpod/screens/onboarding_screen.dart';
import 'package:seedpod/screens/timeline_screen.dart';
import 'package:seedpod/services/log_transfer.dart';
import 'package:seedpod/widgets/quick_log_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _initialized = false;
  bool _reminderSnackShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initLoad();
    }
  }

  Future<void> _initLoad([AppState? state]) async {
    final appState = state ?? context.read<AppState>();
    await appState.loadModulePrefs();
    if (appState.profileState == LoadState.idle) {
      await appState.loadProfile();
    }
    if (appState.entriesState == LoadState.idle && appState.hasBabies) {
      await appState.loadEntries();
    }
  }

  void _openQuickLog([LogType? initialType]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickLogSheet(initialType: initialType),
    );
  }

  Future<void> _onDataMenu(String action) async {
    final state = context.read<AppState>();
    switch (action) {
      case 'export_json':
        await LogTransfer.exportJson(context, state.entries);
      case 'export_csv':
        await LogTransfer.exportCsv(context, state.entries);
      case 'import_json':
        await LogTransfer.importJson(context, state);
      case 'import_csv':
        await LogTransfer.importCsv(context, state);
    }
  }

  Future<void> _openEditProfile(BabyProfile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingScreen.editing(initialProfile: profile),
      ),
    );
  }

  Future<void> _openAddBaby() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  void _openTimeline() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TimelineScreen()),
    );
  }

  void _openVaccines() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HealthScreen(initialTabIndex: 1),
      ),
    );
  }

  void _showReminderSnackBarOnce(int count) {
    if (_reminderSnackShown || count == 0) return;
    _reminderSnackShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$count vaccine reminder${count == 1 ? '' : 's'} '
            'need${count == 1 ? 's' : ''} your attention.',
          ),
        ),
      );
    });
  }

  Future<void> _deleteBaby(BabyProfile baby) async {
    final appState = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${baby.name}?'),
        content: const Text(
          'This will remove this baby profile from your Solid POD. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await appState.deleteBaby(baby.id);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete profile. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Baby profile deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.profileState == LoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!state.hasBabies) {
      return const OnboardingScreen();
    }

    final profile = state.selectedBaby!;
    final vaccineReminders = state.modulePrefs.isEnabled('vaccines')
        ? state.vaccineReminders
        : <VaccineReminder>[];
    _showReminderSnackBarOnce(vaccineReminders.length);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openQuickLog,
        backgroundColor: colorPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Quick Log'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final appState = context.read<AppState>();
          await appState.loadProfile();
          await appState.loadEntries();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _BabySelector(
                      babies: state.babies,
                      selectedBabyId: profile.id,
                      onSelected: state.selectBaby,
                      onAdd: _openAddBaby,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Import / export data',
                    onSelected: _onDataMenu,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'export_json',
                        child: ListTile(
                          leading: Icon(Icons.file_download_outlined),
                          title: Text('Export as JSON'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export_csv',
                        child: ListTile(
                          leading: Icon(Icons.table_view_outlined),
                          title: Text('Export as CSV'),
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'import_json',
                        child: ListTile(
                          leading: Icon(Icons.file_upload_outlined),
                          title: Text('Import from JSON'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'import_csv',
                        child: ListTile(
                          leading: Icon(Icons.upload_file_outlined),
                          title: Text('Import from CSV'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _BabyCard(
                profile: profile,
                onEdit: () => _openEditProfile(profile),
                onDelete: () => _deleteBaby(profile),
              ),
              const SizedBox(height: 24),
              _StatCards(
                entries: state.entries,
                modulePrefs: state.modulePrefs,
              ),
              const SizedBox(height: 16),
              _QuickLogPanel(onLog: _openQuickLog),
              const SizedBox(height: 16),
              if (vaccineReminders.isNotEmpty) ...[
                _VaccinationRemindersCard(
                  reminders: vaccineReminders,
                  onTap: _openVaccines,
                ),
                const SizedBox(height: 16),
              ],
              _RecentLogFooter(
                entries: state.entries,
                entriesState: state.entriesState,
                onViewAll: _openTimeline,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaccinationRemindersCard extends StatelessWidget {
  final List<VaccineReminder> reminders;
  final VoidCallback onTap;

  const _VaccinationRemindersCard({
    required this.reminders,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visible = reminders.take(3).toList();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radiusMedium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.aCard,
          border: Border.all(color: colorPrimary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.vaccines_outlined, color: colorPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vaccination Reminders',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Icon(Icons.chevron_right, color: colorSecondary),
              ],
            ),
            const SizedBox(height: 12),
            for (final reminder in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(
                        _statusIcon(reminder.status),
                        size: 16,
                        color: _statusColor(reminder.status),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reminder.message,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            if (reminders.length > 3)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onTap,
                  child: const Text('View all'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(VaccineReminderStatus status) => switch (status) {
        VaccineReminderStatus.overdue => const Color(0xFFC65D4B),
        VaccineReminderStatus.dueToday => colorAccent,
        VaccineReminderStatus.dueSoon => colorSecondary,
      };

  IconData _statusIcon(VaccineReminderStatus status) => switch (status) {
        VaccineReminderStatus.overdue => Icons.error_outline,
        VaccineReminderStatus.dueToday => Icons.today_outlined,
        VaccineReminderStatus.dueSoon => Icons.schedule,
      };
}

class _BabySelector extends StatelessWidget {
  final List<BabyProfile> babies;
  final String selectedBabyId;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;

  const _BabySelector({
    required this.babies,
    required this.selectedBabyId,
    required this.onSelected,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedBabyId,
            decoration: const InputDecoration(
              labelText: 'Current baby',
              prefixIcon: Icon(Icons.child_care),
            ),
            items: [
              for (final baby in babies)
                DropdownMenuItem(value: baby.id, child: Text(baby.name)),
            ],
            onChanged: (id) {
              if (id != null) onSelected(id);
            },
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add Baby'),
        ),
      ],
    );
  }
}

class _BabyCard extends StatelessWidget {
  final BabyProfile profile;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const _BabyCard({
    required this.profile,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [colorPrimary, Color(0xFF5E9E72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radiusLarge),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.child_care, size: 36, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.ageLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _PodPill(),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onEdit,
                tooltip: 'Edit baby profile',
                icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
              ),
              IconButton(
                onPressed: () => onDelete(),
                tooltip: 'Delete baby profile',
                icon: const Icon(Icons.delete_outline, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodPill extends StatefulWidget {
  @override
  State<_PodPill> createState() => _PodPillState();
}

class _PodPillState extends State<_PodPill> {
  String? _webId;
  late final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = await getWebId();
    if (mounted) setState(() => _webId = id?.toString());
  }

  Future<void> _scrollReveal() async {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (max <= 0) return;
    await _scrollCtrl.animateTo(
      max,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_webId == null) return const SizedBox.shrink();
    final server = Uri.tryParse(_webId!)?.host ?? '';
    return GestureDetector(
      onTap: _scrollReveal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Text(
                  server,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLogPanel extends StatelessWidget {
  final ValueChanged<LogType?> onLog;
  const _QuickLogPanel({required this.onLog});

  static const _pinnedTypes = {
    LogType.growth,
    LogType.sleep,
    LogType.feeding,
  };

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppState>().modulePrefs;
    final pinned = logTypeOptions
        .where(
          (o) => _pinnedTypes.contains(o.type) && prefs.isEnabled(o.moduleId),
        )
        .toList();

    return Row(
      children: [
        for (final opt in pinned) ...[
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: _LogTypeTile(
                option: opt,
                onTap: () => onLog(opt.type),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: AspectRatio(
            aspectRatio: 1.0,
            child: InkWell(
              onTap: () => onLog(null),
              borderRadius: BorderRadius.circular(radiusMedium),
              child: Container(
                decoration: BoxDecoration(
                  color: context.aCard,
                  border: Border.all(color: context.aDivider),
                  borderRadius: BorderRadius.circular(radiusMedium),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apps, color: colorSecondary, size: 20),
                    SizedBox(height: 2),
                    Text(
                      'More',
                      style: TextStyle(fontSize: 10, color: colorSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogTypeTile extends StatelessWidget {
  final LogTypeOption option;
  final VoidCallback onTap;

  const _LogTypeTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radiusMedium),
      child: Container(
        decoration: BoxDecoration(
          color: context.aCard,
          border: Border.all(color: context.aDivider),
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(option.icon, color: colorPrimary, size: 22),
            const SizedBox(height: 4),
            Text(
              option.label,
              style: TextStyle(fontSize: 10, color: context.aText),
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

class _StatCards extends StatelessWidget {
  final List<LogEntry> entries;
  final ModulePrefs modulePrefs;
  const _StatCards({required this.entries, required this.modulePrefs});

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final past24 = entries.where((e) => e.timestamp.isAfter(cutoff)).toList();

    final feedingCount = past24.where((e) => e.type == LogType.feeding).length;
    final nappyCount = past24.where((e) => e.type == LogType.nappy).length;

    double sleepHours = 0;
    for (final e in past24.where((e) => e.type == LogType.sleep)) {
      final start = e.data['start'];
      final end = e.data['end'];
      if (start != null && end != null) {
        try {
          final s = DateTime.parse(start.toString());
          final en = DateTime.parse(end.toString());
          final mins = en.difference(s).inMinutes;
          if (mins > 0) sleepHours += mins / 60.0;
        } catch (_) {}
      }
    }

    final cards = <Widget>[];
    if (modulePrefs.isEnabled('feeding')) {
      cards.add(Expanded(
        child: _StatCard(
          icon: Icons.local_cafe,
          label: 'Feeding',
          value: feedingCount > 0 ? '$feedingCount times' : '—',
        ),
      ),);
    }
    if (modulePrefs.isEnabled('nappy')) {
      cards.add(Expanded(
        child: _StatCard(
          icon: Icons.baby_changing_station,
          label: 'Nappy',
          value: nappyCount > 0 ? '$nappyCount times' : '—',
        ),
      ),);
    }
    if (modulePrefs.isEnabled('sleep')) {
      cards.add(Expanded(
        child: _StatCard(
          icon: Icons.bedtime,
          label: 'Sleep',
          value: sleepHours > 0 ? '${sleepHours.toStringAsFixed(1)} h' : '—',
        ),
      ),);
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    final rowChildren = <Widget>[];
    for (int i = 0; i < cards.length; i++) {
      rowChildren.add(cards[i]);
      if (i < cards.length - 1) rowChildren.add(const SizedBox(width: 8));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PAST 24 HOURS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: rowChildren),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: context.aCard,
        border: Border.all(color: context.aDivider),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        children: [
          Icon(icon, color: colorPrimary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.aText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: colorSecondary),
          ),
        ],
      ),
    );
  }
}

class _RecentLogFooter extends StatelessWidget {
  final List<LogEntry> entries;
  final LoadState entriesState;
  final VoidCallback onViewAll;

  const _RecentLogFooter({
    required this.entries,
    required this.entriesState,
    required this.onViewAll,
  });

  static const Map<LogType, IconData> _icons = {
    LogType.growth: Icons.straighten,
    LogType.sleep: Icons.bedtime,
    LogType.feeding: Icons.local_cafe,
    LogType.milestone: Icons.star,
    LogType.health: Icons.favorite,
    LogType.photo: Icons.photo_camera,
    LogType.environment: Icons.wb_sunny,
    LogType.note: Icons.edit_note,
    LogType.nappy: Icons.baby_changing_station,
    LogType.medication: Icons.medication,
    LogType.food: Icons.restaurant,
    LogType.teeth: Icons.mood,
    LogType.memory: Icons.auto_stories,
    LogType.appointment: Icons.local_hospital,
    LogType.sleep_training: Icons.nightlight,
  };

  @override
  Widget build(BuildContext context) {
    if (entriesState == LoadState.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final now = DateTime.now();
    final todayCount = entries
        .where(
          (e) =>
              e.timestamp.year == now.year &&
              e.timestamp.month == now.month &&
              e.timestamp.day == now.day,
        )
        .length;

    final latest = entries.isEmpty ? null : entries.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.aCard,
        border: Border.all(color: context.aDivider),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Row(
        children: [
          Icon(
            latest != null
                ? (_icons[latest.type] ?? Icons.circle)
                : Icons.wb_sunny_outlined,
            size: 14,
            color: colorSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              latest != null
                  ? '${_time(latest)}  ${_title(latest)}'
                  : 'No entries yet — tap Quick Log to start',
              style: TextStyle(
                fontSize: 13,
                color: latest != null ? colorText : colorSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (todayCount > 0) ...[
            const SizedBox(width: 8),
            Text(
              'Today · $todayCount',
              style: const TextStyle(fontSize: 12, color: colorSecondary),
            ),
          ],
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('View all →'),
          ),
        ],
      ),
    );
  }

  String _time(LogEntry e) {
    final h = e.timestamp.hour.toString().padLeft(2, '0');
    final m = e.timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _title(LogEntry e) {
    switch (e.type) {
      case LogType.growth:
        final w = e.data['weight_kg'];
        final h = e.data['height_cm'];
        if (w != null && w.toString().isNotEmpty) return 'Weight: ${w}kg';
        if (h != null && h.toString().isNotEmpty) return 'Height: ${h}cm';
        return 'Growth measurement';
      case LogType.sleep:
        final start = e.data['start'];
        final end = e.data['end'];
        if (start != null && end != null) {
          try {
            final s = DateTime.parse(start.toString());
            final en = DateTime.parse(end.toString());
            final dur = en.difference(s);
            return 'Slept ${dur.inHours}h ${dur.inMinutes % 60}m';
          } catch (_) {}
        }
        return 'Sleep logged';
      case LogType.feeding:
        final type = e.data['type']?.toString() ?? '';
        final parts = <String>[type.isEmpty ? 'Feeding' : type];
        if (type == 'Breast') {
          final side = e.data['side']?.toString() ?? '';
          if (side.isNotEmpty) parts.add(side);
          final dur = e.data['duration_min']?.toString() ?? '';
          if (dur.isNotEmpty) parts.add('$dur min');
        } else {
          final amt = e.data['amount_ml']?.toString() ?? '';
          if (amt.isNotEmpty) parts.add('${amt}ml');
        }
        return parts.join(' · ');
      case LogType.nappy:
        return 'Nappy — ${e.data['type'] ?? 'change'}';
      case LogType.medication:
        final name = e.data['name']?.toString() ?? 'Medication';
        final dose = e.data['dose']?.toString();
        return dose != null ? '$name — $dose' : name;
      default:
        return e.data['title']?.toString() ?? e.type.label;
    }
  }
}

