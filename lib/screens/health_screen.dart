library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
            _VaccineTab(
              ageInDays: profile?.age.inDays ?? 0,
              dob: profile?.dateOfBirth,
            ),
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

    final dob = state.profile?.dateOfBirth;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'WHO Weight-for-Age',
            subtitle: 'Reference bands P3 / P50 / P97 (0–12 months)',
            child: _WhoChart(entries: growthEntries, dob: dob),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Measurements History',
            child: growthEntries.isEmpty
                ? const _EmptyHint('No growth measurements yet — add one via Quick Log')
                : Column(
                    children: [
                      _MeasurementRow('Date', 'Weight', 'Height', isHeader: true),
                      for (final e in growthEntries.reversed)
                        _MeasurementRow(
                          _shortDate(e.timestamp),
                          e.data['weight_kg']?.toString().isNotEmpty == true
                              ? '${e.data['weight_kg']} kg'
                              : '--',
                          e.data['height_cm']?.toString().isNotEmpty == true
                              ? '${e.data['height_cm']} cm'
                              : '--',
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
  final DateTime? dob;
  const _WhoChart({required this.entries, this.dob});

  // WHO weight-for-age boys (approximation), months 0–12
  static const _p3 = [
    2.5, 3.4, 4.4, 5.1, 5.6, 6.1, 6.4, 6.7, 6.9, 7.1, 7.4, 7.6, 7.7,
  ];
  static const _p50 = [
    3.3, 4.5, 5.6, 6.4, 7.0, 7.5, 7.9, 8.3, 8.6, 8.9, 9.2, 9.4, 9.6,
  ];
  static const _p97 = [
    4.4, 5.8, 7.1, 8.0, 8.7, 9.3, 9.8, 10.2, 10.5, 10.9, 11.2, 11.5, 11.8,
  ];

  List<Offset> _dataPoints() {
    if (dob == null) return [];
    return entries
        .where((e) => e.data['weight_kg']?.toString().isNotEmpty == true)
        .map((e) {
          final months = e.timestamp.difference(dob!).inDays / 30.44;
          final kg = double.tryParse(e.data['weight_kg'].toString()) ?? 0;
          return Offset(months, kg);
        })
        .where((p) => p.dx >= 0 && p.dx <= 12)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentMonths =
        dob != null ? DateTime.now().difference(dob!).inDays / 30.44 : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (ctx, constraints) {
            const h = 200.0;
            return SizedBox(
              width: constraints.maxWidth,
              height: h,
              child: CustomPaint(
                size: Size(constraints.maxWidth, h),
                painter: _GrowthChartPainter(
                  p3: _p3,
                  p50: _p50,
                  p97: _p97,
                  dataPoints: _dataPoints(),
                  currentAgeMonths: currentMonths,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Legend(color: const Color(0xFFBBDFCA), label: 'P3–P97 range'),
            _Legend(color: colorPrimary, label: 'P50 median'),
            _Legend(color: colorAccent, label: 'Your baby'),
            if (dob != null)
              _Legend(
                color: colorAccent.withOpacity(0.5),
                label: 'Current age',
                dashed: true,
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'WHO reference approximation — not a substitute for medical advice',
          style: TextStyle(color: colorSecondary, fontSize: 10),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _Legend({required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: dashed ? 1.5 : 3, color: color),
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
  final double? currentAgeMonths;

  const _GrowthChartPainter({
    required this.p3,
    required this.p50,
    required this.p97,
    required this.dataPoints,
    this.currentAgeMonths,
  });

  static const double _padL = 34.0;
  static const double _padB = 22.0;
  static const double _padT = 6.0;
  static const double _padR = 6.0;
  static const double _minY = 2.0;
  static const double _maxY = 13.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _padL - _padR;
    final chartH = size.height - _padT - _padB;

    Offset toCanvas(double month, double kg) => Offset(
          _padL + (month / 12.0) * chartW,
          _padT + (1.0 - (kg - _minY) / (_maxY - _minY)) * chartH,
        );

    final labelStyle = const TextStyle(color: colorSecondary, fontSize: 9);

    // Horizontal grid lines + Y labels
    final gridPaint = Paint()
      ..color = colorDivider
      ..strokeWidth = 0.5;
    for (final kg in [4.0, 6.0, 8.0, 10.0, 12.0]) {
      final y = _padT + (1.0 - (kg - _minY) / (_maxY - _minY)) * chartH;
      canvas.drawLine(Offset(_padL, y), Offset(size.width - _padR, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: '${kg.toInt()}', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_padL - tp.width - 3, y - tp.height / 2));
    }

    // P3–P97 band fill
    final n = p50.length;
    final bandPath = Path();
    for (int i = 0; i < n; i++) {
      final pt = toCanvas(i.toDouble(), p97[i]);
      if (i == 0) bandPath.moveTo(pt.dx, pt.dy);
      else bandPath.lineTo(pt.dx, pt.dy);
    }
    for (int i = n - 1; i >= 0; i--) {
      final pt = toCanvas(i.toDouble(), p3[i]);
      bandPath.lineTo(pt.dx, pt.dy);
    }
    bandPath.close();
    canvas.drawPath(
      bandPath,
      Paint()..color = const Color(0xFFBBDFCA).withOpacity(0.45),
    );

    // P3 border line
    final borderPaint = Paint()
      ..color = const Color(0xFF4A7C59).withOpacity(0.25)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    _drawLine(canvas, [for (int i = 0; i < n; i++) toCanvas(i.toDouble(), p3[i])], borderPaint);
    _drawLine(canvas, [for (int i = 0; i < n; i++) toCanvas(i.toDouble(), p97[i])], borderPaint);

    // P50 median line
    _drawLine(
      canvas,
      [for (int i = 0; i < n; i++) toCanvas(i.toDouble(), p50[i])],
      Paint()
        ..color = colorPrimary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Current age vertical marker
    if (currentAgeMonths != null &&
        currentAgeMonths! >= 0 &&
        currentAgeMonths! <= 12) {
      final markerX = _padL + (currentAgeMonths! / 12.0) * chartW;
      canvas.drawLine(
        Offset(markerX, _padT),
        Offset(markerX, _padT + chartH),
        Paint()
          ..color = colorAccent.withOpacity(0.5)
          ..strokeWidth = 1.5,
      );
    }

    // Data point dots
    for (final dp in dataPoints) {
      if (dp.dx < 0 || dp.dx > 12) continue;
      final pt = toCanvas(dp.dx, dp.dy);
      canvas.drawCircle(pt, 5, Paint()..color = colorAccent);
      canvas.drawCircle(
        pt,
        5,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }

    // X-axis labels
    for (int i = 0; i <= 12; i += 3) {
      final pt = toCanvas(i.toDouble(), _minY);
      final tp = TextPainter(
        text: TextSpan(text: '${i}m', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pt.dx - tp.width / 2, size.height - _padB + 4));
    }

    // "kg" unit label
    final kgTp = TextPainter(
      text: TextSpan(text: 'kg', style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    kgTp.paint(canvas, Offset(0, _padT));
  }

  void _drawLine(Canvas canvas, List<Offset> pts, Paint paint) {
    if (pts.isEmpty) return;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter old) =>
      old.dataPoints.length != dataPoints.length ||
      old.currentAgeMonths != currentAgeMonths;
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
        ? const TextStyle(color: colorSecondary, fontSize: 12, fontWeight: FontWeight.w600)
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

class _Vaccine {
  final String name;
  final String brand;
  final bool isActFunded;
  const _Vaccine(this.name, this.brand, {this.isActFunded = false});
}

class _VaccineMilestone {
  final String label;
  final int ageDays;
  final List<_Vaccine> vaccines;
  const _VaccineMilestone(this.label, this.ageDays, this.vaccines);
}

const List<_VaccineMilestone> _actSchedule = [
  _VaccineMilestone('Birth', 0, [
    _Vaccine('Hepatitis B', 'Engerix-B or H-B-Vax II Paediatric'),
  ]),
  _VaccineMilestone('6 weeks', 42, [
    _Vaccine('DTPa-hepB-IPV-Hib', 'Infanrix hexa'),
    _Vaccine('Pneumococcal PCV13', 'Prevenar 13'),
    _Vaccine('Rotavirus', 'Rotarix (dose 1 of 2)'),
    _Vaccine('Meningococcal B', 'Bexsero', isActFunded: true),
  ]),
  _VaccineMilestone('4 months', 120, [
    _Vaccine('DTPa-hepB-IPV-Hib', 'Infanrix hexa (2nd dose)'),
    _Vaccine('Pneumococcal PCV13', 'Prevenar 13 (2nd dose)'),
    _Vaccine('Rotavirus', 'Rotarix (dose 2, final)'),
    _Vaccine('Meningococcal B', 'Bexsero (2nd dose)', isActFunded: true),
  ]),
  _VaccineMilestone('6 months', 182, [
    _Vaccine('DTPa-hepB-IPV-Hib', 'Infanrix hexa (3rd dose)'),
    _Vaccine('Meningococcal B', 'Bexsero (3rd dose)', isActFunded: true),
  ]),
  _VaccineMilestone('12 months', 365, [
    _Vaccine('MMR', 'Priorix or M-M-R II'),
    _Vaccine('Meningococcal ACWY', 'Nimenrix or Menactra'),
    _Vaccine('Pneumococcal PCV13', 'Prevenar 13 (3rd dose, booster)'),
    _Vaccine('Varicella (chickenpox)', 'Varilrix or Varivax'),
    _Vaccine('Meningococcal B', 'Bexsero (4th dose, booster)', isActFunded: true),
  ]),
  _VaccineMilestone('18 months', 548, [
    _Vaccine('DTPa', 'Infanrix or Tripacel'),
    _Vaccine('Hib', 'ActHIB or Hiberix'),
    _Vaccine('MMR + Varicella (MMRV)', 'Priorix-Tetra or ProQuad'),
    _Vaccine('Hepatitis A', 'Avaxim Pediatric or Havrix Junior'),
  ]),
  _VaccineMilestone('4 years', 1461, [
    _Vaccine('DTPa-IPV', 'Infanrix IPV or Quadracel'),
    _Vaccine('MMR', 'Priorix or M-M-R II (if not received MMRV at 18 mo)'),
    _Vaccine('Varicella', 'Varilrix or Varivax (if not received MMRV at 18 mo)'),
  ]),
];

class _VaccineTab extends StatefulWidget {
  final int ageInDays;
  final DateTime? dob;
  const _VaccineTab({required this.ageInDays, this.dob});

  @override
  State<_VaccineTab> createState() => _VaccineTabState();
}

class _VaccineTabState extends State<_VaccineTab> {
  // key: "vax_M{mIdx}_V{vIdx}" → ISO date string
  final Map<String, String> _doneMap = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (key.startsWith('vax_')) {
        final val = prefs.getString(key);
        if (val != null) _doneMap[key] = val;
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _toggle(int mIdx, int vIdx, bool done) async {
    final key = 'vax_M${mIdx}_V$vIdx';
    final prefs = await SharedPreferences.getInstance();
    if (done) {
      final date = DateTime.now().toIso8601String();
      await prefs.setString(key, date);
      setState(() => _doneMap[key] = date);
    } else {
      await prefs.remove(key);
      setState(() => _doneMap.remove(key));
    }
  }

  bool _isDone(int mIdx, int vIdx) => _doneMap.containsKey('vax_M${mIdx}_V$vIdx');
  String? _doneDate(int mIdx, int vIdx) => _doneMap['vax_M${mIdx}_V$vIdx'];

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
                    'ACT NIP Schedule (Feb 2025). ACT-funded MenB (Bexsero) is in addition to the national program. Always confirm with your GP or immunisation nurse.',
                    style: TextStyle(color: colorText, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!_loaded)
            const Center(child: CircularProgressIndicator())
          else
            for (int mIdx = 0; mIdx < _actSchedule.length; mIdx++)
              _MilestoneCard(
                milestone: _actSchedule[mIdx],
                currentAgeDays: widget.ageInDays,
                vaccineCount: _actSchedule[mIdx].vaccines.length,
                doneCount: List.generate(
                  _actSchedule[mIdx].vaccines.length,
                  (vIdx) => _isDone(mIdx, vIdx),
                ).where((b) => b).length,
                buildVaccineRow: (vIdx) => _VaccineRow(
                  vaccine: _actSchedule[mIdx].vaccines[vIdx],
                  checked: _isDone(mIdx, vIdx),
                  dateIso: _doneDate(mIdx, vIdx),
                  onChanged: (val) => _toggle(mIdx, vIdx, val ?? false),
                ),
              ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final _VaccineMilestone milestone;
  final int currentAgeDays;
  final int vaccineCount;
  final int doneCount;
  final Widget Function(int vIdx) buildVaccineRow;

  const _MilestoneCard({
    required this.milestone,
    required this.currentAgeDays,
    required this.vaccineCount,
    required this.doneCount,
    required this.buildVaccineRow,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = doneCount == vaccineCount;
    final isDue = currentAgeDays >= milestone.ageDays;

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (allDone) {
      badgeColor = colorPrimary;
      badgeText = 'All done';
      badgeIcon = Icons.check_circle_outline;
    } else if (isDue && doneCount > 0) {
      badgeColor = colorAccent;
      badgeText = '$doneCount/$vaccineCount done';
      badgeIcon = Icons.schedule;
    } else if (isDue) {
      badgeColor = colorAccent;
      badgeText = 'Due now';
      badgeIcon = Icons.notification_important_outlined;
    } else {
      badgeColor = colorSecondary;
      badgeText = 'Upcoming';
      badgeIcon = Icons.calendar_today_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorCard,
        border: Border.all(
          color: allDone ? colorPrimary.withOpacity(0.35) : colorDivider,
        ),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(
                  allDone ? Icons.vaccines : Icons.vaccines_outlined,
                  color: allDone ? colorPrimary : colorSecondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  milestone.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 12, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16, color: colorDivider),
          for (int vIdx = 0; vIdx < milestone.vaccines.length; vIdx++)
            buildVaccineRow(vIdx),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _VaccineRow extends StatelessWidget {
  final _Vaccine vaccine;
  final bool checked;
  final String? dateIso;
  final ValueChanged<bool?> onChanged;

  const _VaccineRow({
    required this.vaccine,
    required this.checked,
    required this.dateIso,
    required this.onChanged,
  });

  String? get _shortDate {
    if (dateIso == null) return null;
    final d = DateTime.tryParse(dateIso!);
    if (d == null) return null;
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: checked,
      onChanged: onChanged,
      activeColor: colorPrimary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      dense: true,
      title: Row(
        children: [
          Expanded(
            child: Text(
              vaccine.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: checked ? colorPrimary : colorText,
              ),
            ),
          ),
          if (vaccine.isActFunded)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ACT',
                style: TextStyle(
                  color: colorAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            vaccine.brand,
            style: const TextStyle(color: colorSecondary, fontSize: 11),
          ),
          if (_shortDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Given: $_shortDate',
                style: const TextStyle(color: colorPrimary, fontSize: 11),
              ),
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

    final today = feedingEntries.where((e) {
      final now = DateTime.now();
      return e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day;
    }).toList();

    final todayTotal = today.fold<double>(
      0,
      (sum, e) => sum + (double.tryParse(e.data['amount_ml']?.toString() ?? '') ?? 0),
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
                _StatBox('${today.length}', 'sessions', Icons.local_cafe),
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
            subtitle: 'General guidance — consult your healthcare provider',
            child: const Column(
              children: [
                _TipCard(
                  'Newborn (0–3 months)',
                  'Breast milk or formula every 2–3 hours, 8–12 times/day',
                ),
                _TipCard(
                  '3–6 months',
                  'Every 3–4 hours; watch for hunger and fullness cues',
                ),
                _TipCard(
                  '6+ months',
                  'Begin introducing solid foods alongside breast milk or formula',
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
            Text(
              label,
              style: const TextStyle(color: colorSecondary, fontSize: 12),
            ),
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
    final side = entry.data['side']?.toString();
    final dur = entry.data['duration_min']?.toString();

    final detail = [
      if (side != null && side.isNotEmpty) side,
      if (amt != null && amt.isNotEmpty) '${amt}ml',
      if (dur != null && dur.isNotEmpty) '${dur}min',
    ].join(' · ');

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
                Text(type, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: const TextStyle(color: colorSecondary, fontSize: 13),
                  ),
              ],
            ),
          ),
          Text(
            '$hour:$min',
            style: const TextStyle(color: colorSecondary, fontSize: 12),
          ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 6, color: colorPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  tip,
                  style: const TextStyle(color: colorSecondary, fontSize: 13),
                ),
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
      width: double.infinity,
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
            Text(subtitle!, style: const TextStyle(color: colorSecondary, fontSize: 12)),
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
        child: Text(message, style: const TextStyle(color: colorSecondary)),
      ),
    );
  }
}
