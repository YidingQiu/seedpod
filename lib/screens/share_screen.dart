library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:seedpod/constants/theme.dart';
import 'package:seedpod/models/baby_profile.dart';
import 'package:seedpod/models/childcare_entry.dart';
import 'package:seedpod/models/log_entry.dart';

// ─── data model ───────────────────────────────────────────────────────────────

class _ResourceItem {
  final String label;
  final String description;
  final IconData icon;
  final String url;
  bool selected;

  _ResourceItem({
    required this.label,
    required this.description,
    required this.icon,
    required this.url,
    this.selected = true,
  });
}

class _ResourceGroup {
  final String label;
  final String description;
  final IconData icon;
  final List<_ResourceItem> items;
  bool expanded;

  _ResourceGroup({
    required this.label,
    required this.description,
    required this.icon,
    required this.items,
    this.expanded = false,
  });

  bool get allSelected => items.every((i) => i.selected);
  bool get noneSelected => items.every((i) => !i.selected);
  bool get someSelected => !allSelected && !noneSelected;

  void selectAll() {
    for (final i in items) {
      i.selected = true;
    }
  }

  void deselectAll() {
    for (final i in items) {
      i.selected = false;
    }
  }

  List<String> get selectedUrls =>
      items.where((i) => i.selected).map((i) => i.url).toList();
}

// ─── screen ───────────────────────────────────────────────────────────────────

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  String? _webId;
  bool _loadingUrls = true;
  List<_ResourceGroup> _groups = [];
  bool _showGrant = false;
  List<String> _grantUrls = [];
  Map<String, String> _titleData = {};
  Key _grantKey = UniqueKey();

  static const _logTypeInfo = <LogType, (IconData, String)>{
    LogType.feeding: (Icons.local_cafe, 'Feeding records'),
    LogType.sleep: (Icons.bedtime, 'Sleep records'),
    LogType.growth: (Icons.straighten, 'Growth measurements'),
    LogType.nappy: (Icons.baby_changing_station, 'Nappy changes'),
    LogType.milestone: (Icons.star, 'Milestones'),
    LogType.health: (Icons.favorite, 'Health notes'),
    LogType.medication: (Icons.medication, 'Medications'),
    LogType.food: (Icons.restaurant, 'Solid foods'),
    LogType.teeth: (Icons.mood, 'Teeth'),
    LogType.appointment: (Icons.local_hospital, 'Doctor appointments'),
    LogType.sleep_training: (Icons.nightlight, 'Sleep training'),
    LogType.memory: (Icons.auto_stories, 'Memories'),
    LogType.note: (Icons.edit_note, 'Notes'),
    LogType.environment: (Icons.wb_sunny, 'Environment'),
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await getWebId();
    if (!mounted) return;
    setState(() => _webId = id?.toString());
    if (id == null) {
      if (mounted) setState(() => _loadingUrls = false);
      return;
    }
    try {
      final dataPath = await getDataDirPath();

      // Per-type log files
      final logItems = <_ResourceItem>[];
      for (final entry in _logTypeInfo.entries) {
        final type = entry.key;
        final (icon, desc) = entry.value;
        final url = await getFileUrl(
          '$dataPath/${LogEntry.fileNameForType(type)}',
        );
        logItems.add(_ResourceItem(
          label: type.label,
          description: desc,
          icon: icon,
          url: url,
        ));
      }

      final childcareUrl =
          await getFileUrl('$dataPath/${ChildcareEntry.fileName}');
      final babyUrl =
          await getFileUrl('$dataPath/${BabyProfile.allProfilesFileName}');

      if (!mounted) return;
      setState(() {
        _groups = [
          _ResourceGroup(
            label: 'Activity Log',
            description: 'Daily tracking data',
            icon: Icons.book_outlined,
            items: logItems,
            expanded: true,
          ),
          _ResourceGroup(
            label: 'Childcare Waitlist',
            description: 'Centre applications and enrolment status',
            icon: Icons.school_outlined,
            items: [
              _ResourceItem(
                label: 'Waitlist data',
                description: 'Centre names, dates, and application status',
                icon: Icons.assignment_outlined,
                url: childcareUrl,
              ),
            ],
            expanded: false,
          ),
          _ResourceGroup(
            label: 'Baby Profile',
            description: 'Basic identity information',
            icon: Icons.child_care_outlined,
            items: [
              _ResourceItem(
                label: 'Profile',
                description: 'Name, date of birth, gender',
                icon: Icons.badge_outlined,
                url: babyUrl,
              ),
            ],
            expanded: false,
          ),
        ];
        _loadingUrls = false;
      });
    } catch (e) {
      debugPrint('ShareScreen: error loading resource URLs: $e');
      if (mounted) setState(() => _loadingUrls = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share Access',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Give caregivers and family access to your baby\'s data — stored privately on your Solid POD.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _HowItWorksCard(),
          const SizedBox(height: 20),
          if (_webId != null) ...[
            _YourWebIdCard(webId: _webId!),
            const SizedBox(height: 20),
          ],
          _buildResourceSection(context),
        ],
      ),
    );
  }

  Widget _buildResourceSection(BuildContext context) {
    if (_loadingUrls) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_webId == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorCard,
          border: Border.all(color: colorDivider),
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        child: Text(
          'Log in to manage sharing permissions.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final anySelected = _groups.any((g) => g.selectedUrls.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manage Permissions',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Choose which data to share, then enter a caregiver\'s WebID. Each row is a separate file on your POD.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),

        // Tree
        Container(
          decoration: BoxDecoration(
            color: colorCard,
            border: Border.all(color: colorDivider),
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          child: Column(
            children: _groups.asMap().entries.map((e) {
              final i = e.key;
              final group = e.value;
              final isLast = i == _groups.length - 1;
              return _GroupTile(
                group: group,
                isLast: isLast,
                onGroupToggle: () => setState(() {
                  if (group.allSelected) {
                    group.deselectAll();
                  } else {
                    group.selectAll();
                  }
                  _showGrant = false;
                }),
                onItemToggle: (item) => setState(() {
                  item.selected = !item.selected;
                  _showGrant = false;
                }),
                onToggleExpand: () =>
                    setState(() => group.expanded = !group.expanded),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        if (!_showGrant) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: anySelected
                  ? () {
                      final allSelected = _groups
                          .expand((g) => g.items.where((i) => i.selected))
                          .toList();
                      setState(() {
                        _showGrant = true;
                        _grantUrls = allSelected.map((i) => i.url).toList();
                        _titleData = {
                          for (final i in allSelected) i.url: i.label,
                        };
                        _grantKey = UniqueKey();
                      });
                    }
                  : null,
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('Set Permissions'),
            ),
          ),
        ] else ...[
          TextButton.icon(
            onPressed: () => setState(() => _showGrant = false),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Change selection'),
          ),
          const SizedBox(height: 8),
          GrantPermissionUi(
            key: _grantKey,
            showAppBar: false,
            resourceNames: _grantUrls,
            titleData: _titleData,
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }
}

// ─── group tile ───────────────────────────────────────────────────────────────

class _GroupTile extends StatelessWidget {
  final _ResourceGroup group;
  final bool isLast;
  final VoidCallback onGroupToggle;
  final ValueChanged<_ResourceItem> onItemToggle;
  final VoidCallback onToggleExpand;

  const _GroupTile({
    required this.group,
    required this.isLast,
    required this.onGroupToggle,
    required this.onItemToggle,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Group header row
        InkWell(
          onTap: onToggleExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: group.someSelected ? null : group.allSelected,
                    tristate: true,
                    onChanged: (_) => onGroupToggle(),
                    activeColor: colorPrimary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(group.icon, size: 18, color: colorPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: colorText,
                        ),
                      ),
                      Text(
                        group.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: colorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  group.expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: colorSecondary,
                ),
              ],
            ),
          ),
        ),

        // Children
        if (group.expanded)
          ...group.items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final isItemLast = i == group.items.length - 1;
            return _ItemTile(
              item: item,
              isLast: isItemLast,
              onToggle: () => onItemToggle(item),
            );
          }),

        if (!isLast) const Divider(height: 1, color: colorDivider),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final _ResourceItem item;
  final bool isLast;
  final VoidCallback onToggle;

  const _ItemTile({
    required this.item,
    required this.isLast,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 12, top: 6, bottom: 6),
        child: Row(
          children: [
            // Tree connector
            SizedBox(
              width: 16,
              child: CustomPaint(
                size: const Size(16, 32),
                painter: _ConnectorPainter(isLast: isLast),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: item.selected,
                onChanged: (_) => onToggle(),
                activeColor: colorPrimary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Icon(item.icon, size: 15, color: colorSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: item.selected ? colorText : colorSecondary,
                    ),
                  ),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: colorSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final bool isLast;
  const _ConnectorPainter({required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorDivider
      ..strokeWidth = 1.5;
    final x = size.width * 0.5;
    final midY = size.height * 0.5;
    canvas.drawLine(Offset(x, 0), Offset(x, isLast ? midY : size.height), paint);
    canvas.drawLine(Offset(x, midY), Offset(size.width, midY), paint);
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) => old.isLast != isLast;
}

// ─── how it works card ────────────────────────────────────────────────────────

class _HowItWorksCard extends StatefulWidget {
  @override
  State<_HowItWorksCard> createState() => _HowItWorksCardState();
}

class _HowItWorksCardState extends State<_HowItWorksCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorPrimary.withValues(alpha: 0.08),
            colorPrimary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorPrimary.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(radiusMedium),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.security, color: colorPrimary, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'How Solid sharing works',
                      style: TextStyle(
                        color: colorPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: colorPrimary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFFD4EAD9)),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  _StepRow(
                    step: '1',
                    title: 'Select what to share',
                    body:
                        'Use the tree to choose which data types to share. Each leaf is a separate file on your POD — real per-type access control.',
                  ),
                  SizedBox(height: 10),
                  _StepRow(
                    step: '2',
                    title: 'Enter the caregiver\'s WebID',
                    body:
                        'They need a free Solid POD at solidcommunity.au. Share your own WebID so they know who to expect.',
                  ),
                  SizedBox(height: 10),
                  _StepRow(
                    step: '3',
                    title: 'Choose read or write access',
                    body:
                        'Read-only lets them view data. Write access lets them add entries too. Revoke at any time.',
                  ),
                  SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _AccessChip(Icons.visibility_outlined, 'Read-only'),
                      _AccessChip(Icons.edit_outlined, 'Write access'),
                      _AccessChip(Icons.block_outlined, 'Revocable'),
                      _AccessChip(Icons.lock_outlined, 'Encrypted'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String step;
  final String title;
  final String body;
  const _StepRow({required this.step, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: colorPrimary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colorText)),
              Text(body,
                  style: const TextStyle(
                      color: colorSecondary, fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── your webid card ─────────────────────────────────────────────────────────

class _YourWebIdCard extends StatelessWidget {
  final String webId;
  const _YourWebIdCard({required this.webId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorCard,
        border: Border.all(color: colorDivider),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_outlined, color: colorPrimary, size: 18),
              SizedBox(width: 8),
              Text(
                'Your WebID',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14, color: colorText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Send this to caregivers so they can add you in their own SeedPod.',
            style: TextStyle(color: colorSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorBg,
              border: Border.all(color: colorDivider),
              borderRadius: BorderRadius.circular(radiusSmall),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    webId,
                    style: const TextStyle(
                        fontSize: 12, color: colorText, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: webId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('WebID copied to clipboard'),
                        duration: Duration(seconds: 2),
                        backgroundColor: colorPrimary,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy, size: 16, color: colorPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── access chip ─────────────────────────────────────────────────────────────

class _AccessChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AccessChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: colorPrimary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorPrimary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: colorPrimary, fontSize: 12)),
        ],
      ),
    );
  }
}
