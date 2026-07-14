library;

import 'package:flutter/material.dart';
import 'package:solidui/solidui.dart';

import 'package:seedpod/constants/theme.dart';

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

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
            'Grant caregivers and family access to your baby\'s data on your Solid POD.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _InfoCard(),
          const SizedBox(height: 24),
          Text(
            'Manage Permissions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const GrantPermissionUi(showAppBar: false),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorPrimary.withOpacity(0.08), colorPrimary.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorPrimary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.security, color: colorPrimary, size: 20),
              SizedBox(width: 8),
              Text(
                'Privacy-first sharing',
                style: TextStyle(
                  color: colorPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your baby\'s data is stored encrypted on your personal Solid POD. '
            'You control exactly who can access what. '
            'Revoke access at any time.',
            style: TextStyle(color: colorText, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _AccessChip(Icons.visibility, 'Read-only'),
              _AccessChip(Icons.edit, 'Write access'),
              _AccessChip(Icons.do_not_disturb, 'Revocable'),
            ],
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
          Text(
            label,
            style: const TextStyle(color: colorPrimary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
