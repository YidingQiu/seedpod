library;

import 'package:flutter/foundation.dart';
import 'package:solidpod/solidpod.dart';

import 'package:seedpod/models/baby_profile.dart';
import 'package:seedpod/models/childcare_entry.dart';
import 'package:seedpod/models/log_entry.dart';

class PodService {
  Future<void> createBaby(BabyProfile baby) async {
    final existing = await _readAllBabies();
    await _writeAllBabies([...existing, baby]);
  }

  Future<List<BabyProfile>> loadBabies() async {
    final babies = await _readAllBabies();
    if (babies.isNotEmpty) {
      if (babies.length == 1) await _assignLegacyLogsTo(babies.single.id);
      return babies;
    }

    final legacy = await _readLegacyBabyProfile();
    if (legacy == null) return [];

    final migrated = legacy.id.isEmpty
        ? legacy.copyWith(id: BabyProfile.generateId())
        : legacy;
    await _writeAllBabies([migrated]);
    await _assignLegacyLogsTo(migrated.id);
    return [migrated];
  }

  Future<void> updateBaby(BabyProfile baby) async {
    final existing = await _readAllBabies();
    final index = existing.indexWhere((b) => b.id == baby.id);
    if (index == -1) {
      await _writeAllBabies([...existing, baby]);
    } else {
      await _writeAllBabies([...existing]..[index] = baby);
    }
  }

  Future<void> deleteBaby(String babyId) async {
    final existing = await _readAllBabies();
    await _writeAllBabies(existing.where((b) => b.id != babyId).toList());
  }

  Future<List<BabyProfile>> _readAllBabies() async {
    try {
      final content = await readPod(BabyProfile.allProfilesFileName);
      return BabyProfile.listFromJsonString(content)
          .where((b) => b.id.isNotEmpty)
          .toList();
    } on ResourceNotExistException {
      return [];
    } catch (e) {
      debugPrint('_readAllBabies error: $e');
      return [];
    }
  }

  Future<void> _writeAllBabies(List<BabyProfile> babies) => writePod(
        BabyProfile.allProfilesFileName,
        BabyProfile.listToJsonString(babies),
        encrypted: true,
        overwrite: true,
      );

  Future<BabyProfile?> _readLegacyBabyProfile() async {
    try {
      final content = await readPod(BabyProfile.fileName);
      return BabyProfile.tryParseJsonString(content);
    } on ResourceNotExistException {
      return null;
    } catch (e) {
      debugPrint('read legacy BabyProfile error: $e');
      rethrow;
    }
  }

  Future<void> _assignLegacyLogsTo(String babyId) async {
    final entries = await readAllLogEntries();
    if (!entries.any((entry) => entry.babyId.isEmpty)) return;
    final migrated = entries
        .map(
          (entry) =>
              entry.babyId.isEmpty ? entry.copyWith(babyId: babyId) : entry,
        )
        .toList();
    await _writeAllLogEntries(migrated);
  }

  Future<List<LogEntry>> readAllLogEntries() async {
    try {
      final content = await readPod(LogEntry.allEntriesFileName);
      final entries = LogEntry.listFromJsonString(content);
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    } on ResourceNotExistException {
      return [];
    } catch (e) {
      debugPrint('readAllLogEntries error: $e');
      return [];
    }
  }

  Future<bool> writeLogEntry(LogEntry entry) async {
    try {
      List<LogEntry> existing = [];
      try {
        final content = await readPod(LogEntry.allEntriesFileName);
        existing = LogEntry.listFromJsonString(content);
      } on ResourceNotExistException {
        // first entry ever
      }
      final updated = [entry, ...existing];
      await _writeAllLogEntries(updated);
      return true;
    } catch (e) {
      debugPrint('writeLogEntry error: $e');
      return false;
    }
  }

  Future<bool> updateLog(LogEntry entry) async {
    try {
      final content = await readPod(LogEntry.allEntriesFileName);
      final existing = LogEntry.listFromJsonString(content);
      final index = existing.indexWhere(
        (item) => item.id == entry.id && item.babyId == entry.babyId,
      );
      if (index == -1) return false;

      final updated = [...existing]..[index] = entry;
      await _writeAllLogEntries(updated);
      return true;
    } catch (e) {
      debugPrint('updateLog error: $e');
      return false;
    }
  }

  /// Overwrites the entire log-entries file. Used for bulk operations such as
  /// import/merge, where writing one entry at a time would be O(n^2).
  Future<bool> writeAllLogEntries(List<LogEntry> entries) async {
    try {
      await _writeAllLogEntries(entries);
      return true;
    } catch (e) {
      debugPrint('writeAllLogEntries error: $e');
      return false;
    }
  }

  Future<void> _writeAllLogEntries(List<LogEntry> entries) => writePod(
        LogEntry.allEntriesFileName,
        LogEntry.listToJsonString(entries),
        encrypted: true,
        overwrite: true,
      );

  Future<List<ChildcareEntry>> readChildcareEntries() async {
    try {
      final content = await readPod(ChildcareEntry.fileName);
      return ChildcareEntry.listFromJsonString(content);
    } on ResourceNotExistException {
      return [];
    } catch (e) {
      debugPrint('readChildcareEntries error: $e');
      return [];
    }
  }

  Future<bool> writeChildcareEntries(List<ChildcareEntry> entries) async {
    try {
      await writePod(
        ChildcareEntry.fileName,
        ChildcareEntry.listToJsonString(entries),
        encrypted: true,
        overwrite: true,
      );
      return true;
    } catch (e) {
      debugPrint('writeChildcareEntries error: $e');
      return false;
    }
  }
}
