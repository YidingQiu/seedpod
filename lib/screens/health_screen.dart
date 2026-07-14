library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seedpod/constants/theme.dart';
import 'package:seedpod/models/log_entry.dart';
import 'package:seedpod/providers/app_state.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: colorBg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            color: colorCard,
            child: const TabBar(
              labelColor: colorPrimary,
              unselectedLabelColor: colorSecondary,
              indicatorColor: colorPrimary,
              tabs: [
                Tab(text: 'Growth'),
                Tab(text: 'Vaccines'),
                Tab(text: 'Feeding'),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _GrowthTab(state: state),
            _VaccineTab(ageInDays: profile?.age.inDays ?? 0),
            _FeedingTab(state: state),
          ],
        ),
      ),
    );
  }
}

// ── Growth Tab ───────────────────────────────────────────────────────────────

class _GrowthTab extends StatelessWidget {
  final AppState state;
  const _GrowthTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final growthEntries = state.entries
        .where((e) => e.type == LogType.growth)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'WHO Growth Reference',
            subtitle: 'Mock data — Typical range for age',
            child: _WhoChart(entries: growthEntries),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Measurements History',
            child: growthEntries.isEmpty
                ? const _EmptyHint('No growth measurements yet')
                : Column(
                    children: [
                      _MeasurementRow('Date', 'Weight', 'Height',
                          isHeader: true),
                      for (final e in growthEntries.reversed)
                        _MeasurementRow(
                          _shortDate(e.timestamp),
                          e.data['weight_kg']?.toString() ?? '--',
                          e.data['height_cm']?.toString() ?? '--',
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year.toString().substring(2)}';
}

class _WhoChart extends StatelessWidget {
  final List<LogEntry> entries;
  const _WhoChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    // Mock WHO percentile bands for 0-12 months
    final mockP3 =
        [3.3, 3.6, 4.1, 4.8, 5.4, 5.8, 6.2, 6.5, 6.8, 7.0, 7.2, 7.4, 7.6];
    final mockP50 =
        [3.9, 4.5, 5.3, 6.1, 6.7, 7.2, 7.6, 7.9, 8.2, 8.5, 8.7, 8.9, 9.2];
    final mockP97 =
        [4.6, 5.4, 6.5, 7.4, 8.1, 8.7, 9.2, 9.6, 10.0, 10.3, 10.6, 10.9, 11.2];

    return Column(
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: colorBg,
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          child: CustomPaint(
            painter: _GrowthChartPainter(
              p3: mockP3,
              p50: mockP50,
              p97: mockP97,
              dataPoints: entries
                  .where((e) => e.data['weight_kg']?.toString().isNotEmpty == true)
                  .map((e) {
                final ageMonths =
                    (e.timestamp.difference(DateTime.now()).inDays.abs()) ~/ 30;
                final w = double.tryParse(e.data['weight_kg'].toString()) ?? 0;
                return Offset(ageMonths.toDouble(), w);
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(color: const Color(0xFFBBDFCA), label: 'P3-P97 range'),
            const SizedBox(width: 16),
            _Legend(color: colorPrimary, label: 'P50 median'),
            const SizedBox(width: 16),
            _Legend(color: colorAccent, label: 'Your baby'),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Mock WHO data for demonstration',
          style: TextStyle(color: colorSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: colorSecondary)),
      ],
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  final List<double> p3;
  final List<double> p50;
  final List<double> p97;
  final List<Offset> dataPoints;

  _GrowthChartPainter({
    required this.p3,
    required this.p50,
    required this.p97,
    required this.dataPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = p50.length;
    final maxY = p97.reduce((a, b) => a > b ? a : b) + 1;
    const minY = 2.0;

    Offset toCanvas(double x, double y) {
      return Offset(
        x / (n - 1) * size.width,
        size.height - (y - minY) / (maxY - minY) * size.height,
      );
    }

    // Fill band P3-P97
    final bandPath = Path();
    for (int i = 0; i < n; i++) {
      final pt = toCanvas(i.toDouble(), p97[i]);
      if (i == 0) {
        bandPath.moveTo(pt.dx, pt.dy);
      } else {
        bandPath.lineTo(pt.dx, pt.dy);
      }
    }
    for (int i = n - 1; i >= 0; i--) {
      final pt = toCanvas(i.toDouble(), p3[i]);
      bandPath.lineTo(pt.dx, pt.dy);
    }
    bandPath.close();
    canvas.drawPath(
      bandPath,
      Paint()..color = const Color(0xFFBBDFCA).withOpacity(0.4),
    );

    // P50 line
    final p50Paint = Paint()
      ..color = colorPrimary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final p50Path = Path();
    for (int i = 0; i < n; i++) {
      final pt = toCanvas(i.toDouble(), p50[i]);
      if (i == 0) {
        p50Path.moveTo(pt.dx, pt.dy);
      } else {
        p50Path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(p50Path, p50Paint);

    // Data points
    final dotPaint = Paint()..color = colorAccent;
    for (final dp in dataPoints) {
      final pt = toCanvas(dp.dx, dp.dy);
      if (pt.dx >= 0 && pt.dx <= size.width) {
        canvas.drawCircle(pt, 5, dotPaint);
      }
    }

    // Axis labels
    final labelStyle = const TextStyle(color: colorSecondary, fontSize: 9);
    for (int i = 0; i < n; i += 3) {
      final pt = toCanvas(i.toDouble(), minY);
      final tp = TextPainter(
        text: TextSpan(text: '${i}m', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pt.dx - tp.width / 2, size.height - 12));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MeasurementRow extends StatelessWidget {
  final String date;
  final String weight;
  final String height;
  final bool isHeader;

  const _MeasurementRow(this.date, this.weight, this.height,
      {this.isHeader = false});

  @override
  Widget build(BuildContext context) {
    final style = isHeader
        ? const TextStyle(
            color: colorSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          )
        : const TextStyle(color: colorText, fontSize: 14);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(date, style: style)),
          Expanded(child: Text(weight, style: style)),
          Expanded(child: Text(height, style: style)),
        ],
      ),
    );
  }
}

// ── Vaccine Tab ──────────────────────────────────────────────────────────────

class _VaccineTab extends StatelessWidget {
  final int ageInDays;
  const _VaccineTab({required this.ageInDays});

  static const _schedule = [
    _VaccineEntry('Birth', 0, ['BCG', 'Hepatitis B (1st dose)'], true),
    _VaccineEntry('6 weeks', 42, [
      'DTPa (1st)',
      'IPV (1st)',
      'Hib (1st)',
      'Hepatitis B (2nd)',
      'PCV (1st)',
      'Rotavirus (1st)',
    ], false),
    _VaccineEntry('4 months', 120, [
      'DTPa (2nd)',
      'IPV (2nd)',
      'Hib (2nd)',
      'PCV (2nd)',
      'Rotavirus (2nd)',
    ], false),
    _VaccineEntry('6 months', 180, [
      'DTPa (3rd)',
      'Hepatitis B (3rd)',
      'Rotavirus (3rd)',
    ], false),
    _VaccineEntry('12 months', 365, [
      'MMR (1st)',
      'Hib (4th)',
      'MenC',
      'PCV (3rd)',
      'Varicella (1st)',
    ], false),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorAccent.withOpacity(0.1),
              border: Border.all(color: colorAccent.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: colorAccent, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mock schedule based on Australian NIP. Always consult your doctor.',
                    style: TextStyle(color: colorText, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final v in _schedule)
            _VaccineCard(entry: v, currentAgeDays: ageInDays),
        ],
      ),
    );
  }
}

class _VaccineEntry {
  final String label;
  final int ageDays;
  final List<String> vaccines;
  final bool givenAtBirth;

  const _VaccineEntry(this.label, this.ageDays, this.vaccines, this.givenAtBirth);
}

class _VaccineCard extends StatelessWidget {
  final _VaccineEntry entry;
  final int currentAgeDays;

  const _VaccineCard({required this.entry, required this.currentAgeDays});

  @override
  Widget build(BuildContext context) {
    final isDue = currentAgeDays >= entry.ageDays;
    final isOverdue = currentAgeDays > entry.ageDays + 14;

    Color badgeColor = colorPrimary;
    String badgeLabel = 'Upcoming';
    if (isDue && !isOverdue) {
      badgeColor = const Color(0xFFE8A87C);
      badgeLabel = 'Due now';
    } else if (isOverdue) {
      badgeColor = const Color(0xFF4A7C59);
      badgeLabel = 'Completed';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                entry.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final v in entry.vaccines)
                Chip(
                  label: Text(v, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  backgroundColor: colorBg,
                  side: const BorderSide(color: colorDivider),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Feeding Tab ──────────────────────────────────────────────────────────────

class _FeedingTab extends StatelessWidget {
  final AppState state;
  const _FeedingTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final feedingEntries = state.entries
        .where((e) => e.type == LogType.feeding)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final today = feedingEntries
        .where(
          (e) =>
              e.timestamp.year == DateTime.now().year &&
              e.timestamp.month == DateTime.now().month &&
              e.timestamp.day == DateTime.now().day,
        )
        .toList();

    final todayTotal = today.fold<double>(
      0,
      (sum, e) =>
          sum + (double.tryParse(e.data['amount_ml']?.toString() ?? '') ?? 0),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: "Today's Feeding",
            child: Row(
              children: [
                _StatBox(
                  '${today.length}',
                  'sessions',
                  Icons.local_cafe,
                ),
                const SizedBox(width: 12),
                _StatBox(
                  todayTotal > 0 ? '${todayTotal.toInt()}ml' : '--',
                  'total volume',
                  Icons.water_drop,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Feeding Log',
            child: feedingEntries.isEmpty
                ? const _EmptyHint('No feeding entries yet')
                : Column(
                    children: [
                      for (final e in feedingEntries.take(20))
                        _FeedingRow(entry: e),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Feeding Tips',
            subtitle: 'Mock guidance — consult your healthcare provider',
            child: const Column(
              children: [
                _TipCard(
                  'Newborn (0-3 months)',
                  'Breast milk or formula every 2-3 hours, 8-12 times/day',
                ),
                _TipCard(
                  '3-6 months',
                  'Every 3-4 hours, watching for hunger/fullness cues',
                ),
                _TipCard(
                  '6+ months',
                  'Begin introducing solid foods alongside breast milk/formula',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatBox(this.value, this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorBg,
          border: Border.all(color: colorDivider),
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        child: Column(
          children: [
            Icon(icon, color: colorPrimary, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colorText,
              ),
            ),
            Text(label, style: const TextStyle(color: colorSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _FeedingRow extends StatelessWidget {
  final LogEntry entry;
  const _FeedingRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hour = entry.timestamp.hour.toString().padLeft(2, '0');
    final min = entry.timestamp.minute.toString().padLeft(2, '0');
    final type = entry.data['type']?.toString() ?? 'Feeding';
    final amt = entry.data['amount_ml']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorAccent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_cafe, color: colorAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (amt != null && amt.isNotEmpty)
                  Text('${amt}ml',
                      style: const TextStyle(
                          color: colorSecondary, fontSize: 13)),
              ],
            ),
          ),
          Text('$hour:$min',
              style: const TextStyle(color: colorSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String title;
  final String tip;
  const _TipCard(this.title, this.tip);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 6, color: colorPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(tip,
                    style: const TextStyle(
                        color: colorSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _SectionCard({required this.title, this.subtitle, required this.child});

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
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: const TextStyle(color: colorSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: colorSecondary),
        ),
      ),
    );
  }
}
