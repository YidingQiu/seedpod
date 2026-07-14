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
    }
  }
}

class LogEntry {
  final String id;
  final LogType type;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const LogEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.data,
  });

  String get fileName => 'log_$id.json.enc.ttl';

  String? get title => data['title'] as String?;
  String? get note => data['note'] as String?;

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String,
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
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'data': data,
      };

  String toJsonString() => jsonEncode(toJson());

  static LogEntry? tryParseJsonString(String jsonString) {
    try {
      return LogEntry.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
