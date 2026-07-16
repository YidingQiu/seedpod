library;

import 'dart:convert';

enum LogType {
  growth,
  sleep,
  feeding,
  milestone,
  health,
  photo,
  environment,
  note,
  nappy,
  medication,
  food,
  teeth,
  memory,
  appointment,
  sleep_training,
}

extension LogTypeLabel on LogType {
  String get label {
    switch (this) {
      case LogType.growth:
        return 'Growth';
      case LogType.sleep:
        return 'Sleep';
      case LogType.feeding:
        return 'Feeding';
      case LogType.milestone:
        return 'Milestone';
      case LogType.health:
        return 'Health';
      case LogType.photo:
        return 'Photo';
      case LogType.environment:
        return 'Environment';
      case LogType.note:
        return 'Note';
      case LogType.nappy:
        return 'Nappy';
      case LogType.medication:
        return 'Medication';
      case LogType.food:
        return 'Food';
      case LogType.teeth:
        return 'Teeth';
      case LogType.memory:
        return 'Memory';
      case LogType.appointment:
        return 'Doctor';
      case LogType.sleep_training:
        return 'Sleep Training';
    }
  }

  String get iconName {
    switch (this) {
      case LogType.growth:
        return 'straighten';
      case LogType.sleep:
        return 'bedtime';
      case LogType.feeding:
        return 'local_cafe';
      case LogType.milestone:
        return 'star';
      case LogType.health:
        return 'favorite';
      case LogType.photo:
        return 'photo_camera';
      case LogType.environment:
        return 'wb_sunny';
      case LogType.note:
        return 'edit_note';
      case LogType.nappy:
        return 'baby_changing_station';
      case LogType.medication:
        return 'medication';
      case LogType.food:
        return 'restaurant';
      case LogType.teeth:
        return 'mood';
      case LogType.memory:
        return 'auto_stories';
      case LogType.appointment:
        return 'local_hospital';
      case LogType.sleep_training:
        return 'nightlight';
    }
  }
}

class LogEntry {
  final String id;
  final String babyId;
  final LogType type;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const LogEntry({
    required this.id,
    this.babyId = '',
    required this.type,
    required this.timestamp,
    required this.data,
  });

  static const String allEntriesFileName = 'log_entries.json.enc.ttl';
  static const String logsDirectory = 'logs';
  // v2 path — each type lives in its own Solid container so it gets its own ACL.
  static String fileNameForType(LogType type) =>
      '$logsDirectory/${type.name}/data.json.enc.ttl';
  static String dirNameForType(LogType type) =>
      '$logsDirectory/${type.name}';

  static List<LogEntry> listFromJsonString(String s) {
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJsonString(List<LogEntry> entries) =>
      jsonEncode(entries.map((e) => e.toJson()).toList());

  String? get title => data['title'] as String?;
  String? get note => data['note'] as String?;

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String,
      babyId: json['babyId'] as String? ?? '',
      type: LogType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => LogType.note,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      data: Map<String, dynamic>.from(json['data'] as Map),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'babyId': babyId,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'data': data,
      };

  LogEntry copyWith({String? babyId}) => LogEntry(
        id: id,
        babyId: babyId ?? this.babyId,
        type: type,
        timestamp: timestamp,
        data: data,
      );

  String toJsonString() => jsonEncode(toJson());

  static LogEntry? tryParseJsonString(String jsonString) {
    try {
      return LogEntry.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
