library;

import 'dart:convert';

class BabyProfile {
  final String name;
  final DateTime dateOfBirth;
  final String? gender;
  final String? photoUrl;

  const BabyProfile({
    required this.name,
    required this.dateOfBirth,
    this.gender,
    this.photoUrl,
  });

  static const String fileName = 'profile.json.enc.ttl';

  Duration get age => DateTime.now().difference(dateOfBirth);

  String get ageLabel {
    final days = age.inDays;
    if (days < 7) return '$days day${days == 1 ? '' : 's'} old';
    if (days < 30) {
      final weeks = days ~/ 7;
      return '$weeks week${weeks == 1 ? '' : 's'} old';
    }
    if (days < 365) {
      final months = days ~/ 30;
      return '$months month${months == 1 ? '' : 's'} old';
    }
    final years = days ~/ 365;
    final remMonths = (days % 365) ~/ 30;
    if (remMonths == 0) return '$years year${years == 1 ? '' : 's'} old';
    return '$years yr $remMonths mo old';
  }

  factory BabyProfile.fromJson(Map<String, dynamic> json) {
    return BabyProfile(
      name: json['name'] as String,
      dateOfBirth: DateTime.parse(json['dateOfBirth'] as String),
      gender: json['gender'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        if (gender != null) 'gender': gender,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  String toJsonString() => jsonEncode(toJson());

  static BabyProfile? tryParseJsonString(String jsonString) {
    try {
      return BabyProfile.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  BabyProfile copyWith({
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    String? photoUrl,
  }) {
    return BabyProfile(
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
