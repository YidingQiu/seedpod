library;

import 'package:seedpod/models/baby_profile.dart';

enum VaccineReminderStatus { overdue, dueToday, dueSoon }

class VaccineReminder {
  final String babyId;
  final String vaccineId;
  final String vaccineName;
  final DateTime dueDate;
  final VaccineReminderStatus status;
  final int daysRemaining;

  const VaccineReminder({
    required this.babyId,
    required this.vaccineId,
    required this.vaccineName,
    required this.dueDate,
    required this.status,
    required this.daysRemaining,
  });

  String get message {
    switch (status) {
      case VaccineReminderStatus.overdue:
        return '$vaccineName is overdue.';
      case VaccineReminderStatus.dueToday:
        return '$vaccineName is due today.';
      case VaccineReminderStatus.dueSoon:
        return '$vaccineName is due in $daysRemaining '
            'day${daysRemaining == 1 ? '' : 's'}.';
    }
  }
}

class VaccineDefinition {
  final String name;
  final String brand;
  final bool isActFunded;

  const VaccineDefinition(
    this.name,
    this.brand, {
    this.isActFunded = false,
  });
}

class VaccineMilestone {
  final String label;
  final int ageDays;
  final List<VaccineDefinition> vaccines;

  const VaccineMilestone(this.label, this.ageDays, this.vaccines);
}

const List<VaccineMilestone> actVaccineSchedule = [
  VaccineMilestone('Birth', 0, [
    VaccineDefinition('Hepatitis B', 'Engerix-B or H-B-Vax II Paediatric'),
  ]),
  VaccineMilestone('6 weeks', 42, [
    VaccineDefinition('DTPa-hepB-IPV-Hib', 'Infanrix hexa'),
    VaccineDefinition('Pneumococcal PCV13', 'Prevenar 13'),
    VaccineDefinition('Rotavirus', 'Rotarix (dose 1 of 2)'),
    VaccineDefinition(
      'Meningococcal B',
      'Bexsero',
      isActFunded: true,
    ),
  ]),
  VaccineMilestone('4 months', 120, [
    VaccineDefinition('DTPa-hepB-IPV-Hib', 'Infanrix hexa (2nd dose)'),
    VaccineDefinition('Pneumococcal PCV13', 'Prevenar 13 (2nd dose)'),
    VaccineDefinition('Rotavirus', 'Rotarix (dose 2, final)'),
    VaccineDefinition(
      'Meningococcal B',
      'Bexsero (2nd dose)',
      isActFunded: true,
    ),
  ]),
  VaccineMilestone('6 months', 182, [
    VaccineDefinition('DTPa-hepB-IPV-Hib', 'Infanrix hexa (3rd dose)'),
    VaccineDefinition(
      'Meningococcal B',
      'Bexsero (3rd dose)',
      isActFunded: true,
    ),
  ]),
  VaccineMilestone('12 months', 365, [
    VaccineDefinition('MMR', 'Priorix or M-M-R II'),
    VaccineDefinition('Meningococcal ACWY', 'Nimenrix or Menactra'),
    VaccineDefinition(
      'Pneumococcal PCV13',
      'Prevenar 13 (3rd dose, booster)',
    ),
    VaccineDefinition(
      'Varicella (chickenpox)',
      'Varilrix or Varivax',
    ),
    VaccineDefinition(
      'Meningococcal B',
      'Bexsero (4th dose, booster)',
      isActFunded: true,
    ),
  ]),
  VaccineMilestone('18 months', 548, [
    VaccineDefinition('DTPa', 'Infanrix or Tripacel'),
    VaccineDefinition('Hib', 'ActHIB or Hiberix'),
    VaccineDefinition(
      'MMR + Varicella (MMRV)',
      'Priorix-Tetra or ProQuad',
    ),
    VaccineDefinition(
      'Hepatitis A',
      'Avaxim Pediatric or Havrix Junior',
    ),
  ]),
  VaccineMilestone('4 years', 1461, [
    VaccineDefinition('DTPa-IPV', 'Infanrix IPV or Quadracel'),
    VaccineDefinition(
      'MMR',
      'Priorix or M-M-R II (if not received MMRV at 18 mo)',
    ),
    VaccineDefinition(
      'Varicella',
      'Varilrix or Varivax (if not received MMRV at 18 mo)',
    ),
  ]),
];

String vaccineId(int milestoneIndex, int vaccineIndex) =>
    'M${milestoneIndex}_V$vaccineIndex';

DateTime vaccineDueDate(DateTime dateOfBirth, int ageDays) {
  final birthDate = DateTime(
    dateOfBirth.year,
    dateOfBirth.month,
    dateOfBirth.day,
  );
  return birthDate.add(Duration(days: ageDays));
}

List<VaccineReminder> deriveVaccineReminders({
  required BabyProfile baby,
  required Set<String> completedVaccineIds,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final reminders = <VaccineReminder>[];

  for (var mIdx = 0; mIdx < actVaccineSchedule.length; mIdx++) {
    final milestone = actVaccineSchedule[mIdx];
    final dueDate = vaccineDueDate(baby.dateOfBirth, milestone.ageDays);
    final daysRemaining = dueDate.difference(today).inDays;
    if (daysRemaining > 7) continue;

    for (var vIdx = 0; vIdx < milestone.vaccines.length; vIdx++) {
      final id = vaccineId(mIdx, vIdx);
      if (completedVaccineIds.contains(id)) continue;
      final status = daysRemaining < 0
          ? VaccineReminderStatus.overdue
          : daysRemaining == 0
              ? VaccineReminderStatus.dueToday
              : VaccineReminderStatus.dueSoon;
      reminders.add(
        VaccineReminder(
          babyId: baby.id,
          vaccineId: id,
          vaccineName: milestone.vaccines[vIdx].name,
          dueDate: dueDate,
          status: status,
          daysRemaining: daysRemaining,
        ),
      );
    }
  }

  reminders.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return reminders;
}
