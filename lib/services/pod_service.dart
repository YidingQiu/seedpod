library;

import 'package:flutter/foundation.dart';
import 'package:solidpod/solidpod.dart';

import 'package:seedpod/models/baby_profile.dart';
import 'package:seedpod/models/log_entry.dart';

class PodService {
  Future<BabyProfile?> readBabyProfile() async {
    try {
      final content = await readPod(BabyProfile.fileName);
      return BabyProfile.tryParseJsonString(content);
    } on ResourceNotExistException {
      return null;
    } catch (e) {
      debugPrint('readBabyProfile error: $e');
      return null;
    }
  }

  Future<bool> writeBabyProfile(BabyProfile profile) async {
    try {
      await writePod(
        BabyProfile.fileName,
        profile.toJsonString(),
        encrypted: true,
        overwrite: true,
      );
      return true;
    } catch (e) {
      debugPrint('writeBabyProfile error: $e');
      return false;
    }
  }

  Future<List<LogEntry>> readAllLogEntries() async {
    try {
      final files = await getResources();
      final logFiles =
          files.where((f) => _basename(f).startsWith('log_')).toList();

      final entries = <LogEntry>[];
      for (final filePath in logFiles) {
        try {
          final fileName = _basename(filePath);
          final content = await readPod(fileName);
          final entry = LogEntry.tryParseJsonString(content);
          if (entry != null) entries.add(entry);
        } catch (e) {
          debugPrint('readLogEntry error for $filePath: $e');
        }
      }

      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    } catch (e) {
      debugPrint('readAllLogEntries error: $e');
      return [];
    }
  }

  Future<bool> writeLogEntry(LogEntry entry) async {
    try {
      await writePod(
        entry.fileName,
        entry.toJsonString(),
        encrypted: true,
      );
      return true;
    } catch (e) {
      debugPrint('writeLogEntry error: $e');
      return false;
    }
  }

  String _basename(String path) {
    final idx = path.lastIndexOf('/');
    return idx >= 0 ? path.substring(idx + 1) : path;
  }
}
