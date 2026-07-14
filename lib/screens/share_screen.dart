library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:seedpod/constants/theme.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  String? _webId;

  @override
  void initState() {
    super.initState();
    _loadWebId();
  }

  Future<void> _loadWebId() async {
    final id = await getWebId();
    if (mounted) setState(() => _webId = id?.toString());
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

          // How Solid sharing works
          _HowItWorksCard(),
          const SizedBox(height: 20),

          // Your identity card
          if (_webId != null) ...[
            _YourWebIdCard(webId: _webId!),
            const SizedBox(height: 20),
          ],

          // Grant permissions
          Text(
            'Manage Permissions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the WebID of the person you want to grant access to.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          const GrantPermissionUi(showAppBar: false),
        ],
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
            colorPrimary.withOpacity(0.08),
            colorPrimary.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorPrimary.withOpacity(0.2)),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  _StepRow(
                    step: '1',
                    title: 'Share your WebID',
                    body:
                        'Your WebID is your Solid identity. Copy it and send it to the caregiver so they know who you are.',
                  ),
                  const SizedBox(height: 10),
                  _StepRow(
                    step: '2',
                    title: 'They get a WebID too',
                    body:
                        'The other person creates a free Solid POD at solidcommunity.au and gets their own WebID.',
                  ),
                  const SizedBox(height: 10),
                  _StepRow(
                    step: '3',
                    title: 'Grant access below',
                    body:
                        'Enter their WebID in the form below. Choose read-only or read/write access. They can only see what you explicitly allow.',
                  ),
                  const SizedBox(height: 10),
                  _StepRow(
                    step: '4',
                    title: 'They log in and view your data',
                    body:
                        'The caregiver opens SeedPod, logs in with their account, and can now see your baby\'s shared data. You can revoke access any time.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
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
        border: Border.all(color: colorPrimary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorPrimary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: colorPrimary, fontSize: 12)),
        ],
      ),
    );
  }
}
