library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:seedpod/constants/theme.dart';
import 'package:seedpod/models/childcare_entry.dart';
import 'package:seedpod/models/log_entry.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  String? _webId;
  bool _loadingUrls = true;
  final Map<String, String> _urlByLabel = {};
  final Map<String, String> _descByLabel = {};
  Set<String> _selectedUrls = {};
  bool _showGrant = false;
  List<String> _grantUrls = [];
  Key _grantKey = UniqueKey();

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
      final logUrl =
          await getFileUrl('$dataPath/${LogEntry.allEntriesFileName}');
      final childcareUrl =
          await getFileUrl('$dataPath/${ChildcareEntry.fileName}');
      if (!mounted) return;
      setState(() {
        _urlByLabel['Activity Log'] = logUrl;
        _descByLabel['Activity Log'] =
            'Feeding, sleep, nappy, growth and all other log entries';
        _urlByLabel['Childcare Waitlist'] = childcareUrl;
        _descByLabel['Childcare Waitlist'] =
            'Waitlist applications and enrolment status for childcare centres';
        _selectedUrls = {logUrl, childcareUrl};
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
          Text(
            'Share Access',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage Permissions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Choose which parts of your data to share, then enter a caregiver\'s WebID to grant them access.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),

        // Resource checkboxes
        ..._urlByLabel.entries.map((entry) {
          final label = entry.key;
          final url = entry.value;
          final checked = _selectedUrls.contains(url);
          return _ResourceCheckTile(
            label: label,
            description: _descByLabel[label] ?? '',
            checked: checked,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedUrls.add(url);
                } else {
                  _selectedUrls.remove(url);
                }
                _showGrant = false;
              });
            },
          );
        }),

        const SizedBox(height: 16),

        if (!_showGrant) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedUrls.isEmpty
                  ? null
                  : () {
                      setState(() {
                        _showGrant = true;
                        _grantUrls = _selectedUrls.toList();
                        _grantKey = UniqueKey();
                      });
                    },
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
            titleData: {
              for (final e in _urlByLabel.entries) e.value: e.key,
            },
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }
}

class _ResourceCheckTile extends StatelessWidget {
  final String label;
  final String description;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  const _ResourceCheckTile({
    required this.label,
    required this.description,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorCard,
        border: Border.all(
          color: checked ? colorPrimary.withValues(alpha:0.35) : colorDivider,
        ),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: CheckboxListTile(
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            description,
            style: const TextStyle(
              color: colorSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
        value: checked,
        onChanged: onChanged,
        activeColor: colorPrimary,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

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
            colorPrimary.withValues(alpha:0.08),
            colorPrimary.withValues(alpha:0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorPrimary.withValues(alpha:0.2)),
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
                  const _StepRow(
                    step: '1',
                    title: 'Share your WebID',
                    body:
                        'Your WebID is your Solid identity. Copy it and send it to the caregiver so they know who you are.',
                  ),
                  const SizedBox(height: 10),
                  const _StepRow(
                    step: '2',
                    title: 'They get a WebID too',
                    body:
                        'The other person creates a free Solid POD at solidcommunity.au and gets their own WebID.',
                  ),
                  const SizedBox(height: 10),
                  const _StepRow(
                    step: '3',
                    title: 'Select resources and set permissions',
                    body:
                        'Tick the data you want to share, press Set Permissions, then enter their WebID and choose read or write access.',
                  ),
                  const SizedBox(height: 10),
                  const _StepRow(
                    step: '4',
                    title: 'They log in and view your data',
                    body:
                        'The caregiver opens SeedPod, logs in with their account, and can now see your baby\'s shared data. You can revoke access any time.',
                  ),
                  const SizedBox(height: 14),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _AccessChip(Icons.visibility_outlined, 'Read-only'),
                      _AccessChip(Icons.edit_outlined, 'Write access'),
                      _AccessChip(Icons.block_outlined, 'Revocable'),
                      _AccessChip(Icons.lock_outlined, 'End-to-end encrypted'),
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
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colorText,
                ),
              ),
              Text(
                body,
                style: const TextStyle(
                  color: colorSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: colorText,
                ),
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
                      fontSize: 12,
                      color: colorText,
                      fontFamily: 'monospace',
                    ),
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
        border: Border.all(color: colorPrimary.withValues(alpha:0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorPrimary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: colorPrimary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
