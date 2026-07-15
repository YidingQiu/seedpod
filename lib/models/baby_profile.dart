library;

import 'dart:convert';
import 'dart:math';

class BabyProfile {
  final String id;
  final String name;
  final DateTime dateOfBirth;
  final String? gender;
  final String? photoUrl;
  final String? webId;

  const BabyProfile({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    this.gender,
    this.photoUrl,
    this.webId,
  });

  static const String fileName = 'profile.json.enc.ttl';
  static const String allProfilesFileName = 'babies.json.enc.ttl';
  static const String babiesDirectory = 'babies';

  static List<BabyProfile> listFromJsonString(String s) {
    try {
      final list = jsonDecode(s) as List;
      return list
          .map((e) => BabyProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJsonString(List<BabyProfile> babies) =>
      jsonEncode(babies.map((b) => b.toJson()).toList());

  static String generateId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static String fileNameFor(String id) =>
      '$babiesDirectory/baby_$id.json.enc.ttl';

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
      id: json['id'] as String? ?? '',
      name: json['name'] as String,
      dateOfBirth: DateTime.parse(json['dateOfBirth'] as String),
      gender: json['gender'] as String?,
      photoUrl: json['photoUrl'] as String?,
      webId: json['webId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        if (gender != null) 'gender': gender,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (webId != null) 'webId': webId,
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
    String? id,
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    String? photoUrl,
    String? webId,
  }) {
    return BabyProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      webId: webId ?? this.webId,
    );
  }
}
