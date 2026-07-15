library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seedpod/constants/theme.dart';
import 'package:seedpod/models/module_prefs.dart';
import 'package:seedpod/providers/app_state.dart';

class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppState>().modulePrefs;
    final optional = ModulePrefs.allModules.where((m) => !m.isCore).toList();

    final categories = <String, List<SeedPodModule>>{};
    for (final m in optional) {
      categories.putIfAbsent(m.category, () => []).add(m);
    }

    return Scaffold(
      backgroundColor: colorBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Modules',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Choose what you want to track. All modules are available from birth — suggestions are just hints.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            // Core modules (read-only)
            _SectionHeader('Core — Always On'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ModulePrefs.allModules
                  .where((m) => m.isCore)
                  .map((m) => _CoreChip(m.title))
                  .toList(),
            ),
            const SizedBox(height: 24),

            // Optional module categories
            for (final category in categories.keys) ...[
              _SectionHeader(category),
              const SizedBox(height: 10),
              ...categories[category]!.map(
                (m) => _ModuleCard(
                  module: m,
                  enabled: prefs.isEnabled(m.id),
                  onToggle: () => context.read<AppState>().toggleModule(m.id),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Future custom module hint
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorCard,
                border:
                    Border.all(color: colorDivider, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(radiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline,
                      color: colorSecondary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Custom module',
                          style: TextStyle(
                            color: colorSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Coming soon — define your own tracking fields.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Soon',
                      style: TextStyle(color: colorSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: colorSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: colorDivider)),
      ],
    );
  }
}

class _CoreChip extends StatelessWidget {
  final String label;
  const _CoreChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorPrimary.withOpacity(0.1),
        border: Border.all(color: colorPrimary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, size: 12, color: colorPrimary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: colorPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final SeedPodModule module;
  final bool enabled;
  final VoidCallback onToggle;

  const _ModuleCard({
    required this.module,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorCard,
        border: Border.all(
          color: enabled ? colorPrimary.withOpacity(0.3) : colorDivider,
        ),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Row(
          children: [
            Text(
              module.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: enabled ? colorText : colorSecondary,
              ),
            ),
            const SizedBox(width: 8),
            if (module.suggestedFrom != 'Birth')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  module.suggestedFrom,
                  style: const TextStyle(
                    color: colorAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            module.description,
            style: const TextStyle(
                color: colorSecondary, fontSize: 12, height: 1.3),
          ),
        ),
        trailing: Switch(
          value: enabled,
          onChanged: (_) => onToggle(),
          activeColor: colorPrimary,
        ),
        onTap: onToggle,
      ),
    );
  }
}
