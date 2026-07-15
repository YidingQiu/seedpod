library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solidpod/solidpod.dart';

import 'package:seedpod/constants/theme.dart';
import 'package:seedpod/models/baby_profile.dart';
import 'package:seedpod/models/log_entry.dart';
import 'package:seedpod/providers/app_state.dart';
import 'package:seedpod/screens/onboarding_screen.dart';
import 'package:seedpod/widgets/quick_log_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _initialized = false;

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

  void _openEditLog(LogEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickLogSheet(entry: entry),
    );
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
    final todayLogs = state.todayEntries;

    return Scaffold(
      backgroundColor: colorBg,
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
              _BabySelector(
                babies: state.babies,
                selectedBabyId: profile.id,
                onSelected: state.selectBaby,
                onAdd: _openAddBaby,
              ),
              const SizedBox(height: 16),
              _BabyCard(
                profile: profile,
                onEdit: () => _openEditProfile(profile),
                onDelete: () => _deleteBaby(profile),
              ),
              const SizedBox(height: 24),
              _QuickActions(onLog: _openQuickLog),
              const SizedBox(height: 24),
              Text(
                "Today's Log",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (state.entriesState == LoadState.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (todayLogs.isEmpty)
                _EmptyToday(onLog: _openQuickLog)
              else
                for (final entry in todayLogs)
                  _LogCard(
                    entry: entry,
                    onEdit: () => _openEditLog(entry),
                  ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await getWebId();
    if (mounted) setState(() => _webId = id?.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (_webId == null) return const SizedBox.shrink();
    final server = Uri.tryParse(_webId!)?.host ?? '';
    return Container(
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
          Text(
            server,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<LogType?> onLog;
  const _QuickActions({required this.onLog});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child:
                _ActionChip(Icons.straighten, 'Growth', LogType.growth, onLog)),
        const SizedBox(width: 8),
        Expanded(
            child: _ActionChip(Icons.bedtime, 'Sleep', LogType.sleep, onLog)),
        const SizedBox(width: 8),
        Expanded(
            child: _ActionChip(
                Icons.local_cafe, 'Feeding', LogType.feeding, onLog)),
        const SizedBox(width: 8),
        Expanded(
            child:
                _ActionChip(Icons.star, 'Milestone', LogType.milestone, onLog)),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final LogType type;
  final ValueChanged<LogType?> onLog;

  const _ActionChip(this.icon, this.label, this.type, this.onLog);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onLog(type),
      borderRadius: BorderRadius.circular(radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colorCard,
          border: Border.all(color: colorDivider),
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        child: Column(
          children: [
            Icon(icon, color: colorPrimary, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: colorText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  final VoidCallback onLog;
  const _EmptyToday({required this.onLog});

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
          const Icon(Icons.wb_sunny_outlined, size: 40, color: colorSecondary),
          const SizedBox(height: 12),
          Text(
            'No entries yet today',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Tap Quick Log to record feeding, sleep, growth and more.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onLog,
            icon: const Icon(Icons.add),
            label: const Text('Add First Log'),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final LogEntry entry;
  final VoidCallback onEdit;
  const _LogCard({required this.entry, required this.onEdit});

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
    final hour = entry.timestamp.hour.toString().padLeft(2, '0');
    final min = entry.timestamp.minute.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorCard,
        border: Border.all(color: colorDivider),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _icons[entry.type] ?? Icons.circle,
              color: colorPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _buildTitle(entry),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (entry.note != null && entry.note!.isNotEmpty)
                  Text(
                    entry.note!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            '$hour:$min',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          IconButton(
            onPressed: onEdit,
            tooltip: 'Edit log',
            icon: const Icon(Icons.edit_outlined),
            color: colorPrimary,
          ),
        ],
      ),
    );
  }

  String _buildTitle(LogEntry e) {
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
          final s = DateTime.parse(start.toString());
          final en = DateTime.parse(end.toString());
          final dur = en.difference(s);
          return 'Slept ${dur.inHours}h ${dur.inMinutes % 60}m';
        }
        return 'Sleep logged';
      case LogType.feeding:
        final t = e.data['type'] ?? 'Feeding';
        final amt = e.data['amount_ml'];
        if (amt != null && amt.toString().isNotEmpty) return '$t - ${amt}ml';
        return '$t feeding';
      case LogType.milestone:
        return e.data['title']?.toString() ?? 'Milestone';
      case LogType.nappy:
        return 'Nappy — ${e.data['type'] ?? 'change'}';
      case LogType.medication:
        final name = e.data['name']?.toString() ?? 'Medication';
        final dose = e.data['dose']?.toString();
        return dose != null ? '$name — $dose' : name;
      case LogType.food:
        final food = e.data['name']?.toString() ?? 'Food';
        final reaction = e.data['reaction']?.toString();
        if (reaction != null && reaction != 'None')
          return '$food (reaction: $reaction)';
        return 'First food: $food';
      case LogType.teeth:
        return e.data['tooth']?.toString() ?? 'Tooth eruption';
      case LogType.memory:
        return e.data['title']?.toString() ?? 'Memory';
      case LogType.appointment:
        final type = e.data['type']?.toString() ?? 'Appointment';
        final doc = e.data['doctor']?.toString();
        return doc != null ? '$type — $doc' : type;
      case LogType.sleep_training:
        return e.data['method']?.toString() ?? 'Sleep training';
      default:
        return e.data['title']?.toString() ?? e.type.label;
    }
  }
}
