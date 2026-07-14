library;

import 'dart:convert';

class ChildcareEntry {
  final String id;
  final String centerName;
  final String? suburb;
  final String? type;
  final DateTime appliedDate;
  final DateTime? desiredStartDate;
  final String status;
  final double? dailyFeeAud;
  final int? waitlistPosition;
  final String? notes;

  const ChildcareEntry({
    required this.id,
    required this.centerName,
    this.suburb,
    this.type,
    required this.appliedDate,
    this.desiredStartDate,
    this.status = 'applied',
    this.dailyFeeAud,
    this.waitlistPosition,
    this.notes,
  });

  static const String fileName = 'childcare_list.json.enc.ttl';

  static const List<String> statusOptions = [
    'applied',
    'waitlisted',
    'offered',
    'enrolled',
    'declined',
  ];

  static const List<String> typeOptions = [
    'Long Day Care',
    'Family Day Care',
    'Outside School Hours Care',
    'Public School',
    'Catholic School',
    'Independent School',
  ];

  factory ChildcareEntry.fromJson(Map<String, dynamic> json) => ChildcareEntry(
        id: json['id'] as String,
        centerName: json['centerName'] as String,
        suburb: json['suburb'] as String?,
        type: json['type'] as String?,
        appliedDate: DateTime.parse(json['appliedDate'] as String),
        desiredStartDate: json['desiredStartDate'] != null
            ? DateTime.parse(json['desiredStartDate'] as String)
            : null,
        status: json['status'] as String? ?? 'applied',
        dailyFeeAud: (json['dailyFeeAud'] as num?)?.toDouble(),
        waitlistPosition: json['waitlistPosition'] as int?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'centerName': centerName,
        if (suburb != null) 'suburb': suburb,
        if (type != null) 'type': type,
        'appliedDate': appliedDate.toIso8601String(),
        if (desiredStartDate != null)
          'desiredStartDate': desiredStartDate!.toIso8601String(),
        'status': status,
        if (dailyFeeAud != null) 'dailyFeeAud': dailyFeeAud,
        if (waitlistPosition != null) 'waitlistPosition': waitlistPosition,
        if (notes != null) 'notes': notes,
      };

  static List<ChildcareEntry> listFromJsonString(String s) {
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => ChildcareEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJsonString(List<ChildcareEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  ChildcareEntry copyWith({
    String? centerName,
    String? suburb,
    String? type,
    DateTime? appliedDate,
    DateTime? desiredStartDate,
    String? status,
    double? dailyFeeAud,
    int? waitlistPosition,
    String? notes,
  }) =>
      ChildcareEntry(
        id: id,
        centerName: centerName ?? this.centerName,
        suburb: suburb ?? this.suburb,
        type: type ?? this.type,
        appliedDate: appliedDate ?? this.appliedDate,
        desiredStartDate: desiredStartDate ?? this.desiredStartDate,
        status: status ?? this.status,
        dailyFeeAud: dailyFeeAud ?? this.dailyFeeAud,
        waitlistPosition: waitlistPosition ?? this.waitlistPosition,
        notes: notes ?? this.notes,
      );
}
