library;

import 'package:flutter/foundation.dart';
import 'package:solidpod/solidpod.dart';

import 'package:seedpod/models/baby_profile.dart';
import 'package:seedpod/models/childcare_entry.dart';
import 'package:seedpod/models/log_entry.dart';

class PodService {
  // ─── baby profiles ─────────────────────────────────────────────────────────

  Future<void> createBaby(BabyProfile baby) async {
    await _writeBaby(baby, overwrite: false);
  }

  Future<List<BabyProfile>> loadBabies() async {
    final babies = await _loadBabiesDirectory();
    if (babies.isNotEmpty) {
      if (babies.length == 1) await _assignLegacyLogsTo(babies.single.id);
      return babies;
    }

    final legacy = await _readLegacyBabyProfile();
    if (legacy == null) return [];

    final migrated = legacy.copyWith(id: BabyProfile.generateId());
    await createBaby(migrated);
    await _assignLegacyLogsTo(migrated.id);
    return [migrated];
  }

  Future<void> updateBaby(BabyProfile baby) async {
    await _writeBaby(baby, overwrite: true);
  }

  Future<void> deleteBaby(String babyId) async {
    try {
      final fileUrl = await getFileUrl(
        '${await getDataDirPath()}/${BabyProfile.fileNameFor(babyId)}',
      );
      await deleteFile(fileUrl: fileUrl);
    } on ResourceNotExistException {
      return;
    }
  }

  Future<void> _writeBaby(BabyProfile baby, {required bool overwrite}) async {
    await writePod(
      BabyProfile.fileNameFor(baby.id),
      baby.toJsonString(),
      encrypted: true,
      overwrite: overwrite,
    );
  }

  Future<List<BabyProfile>> _loadBabiesDirectory() async {
    try {
      final dataPath = await getDataDirPath();
      final directoryUrl = await getDirUrl(
        '$dataPath/${BabyProfile.babiesDirectory}',
      );
      final status = await checkResourceStatus(directoryUrl, isFile: false);
      if (status == ResourceStatus.notExist) return [];
      if (status != ResourceStatus.exist) {
        throw Exception('Unable to access the babies directory ($status)');
      }
      final resources = await getResourcesInContainer(directoryUrl);
      final babies = <BabyProfile>[];
      for (final resource in resources.files) {
        final name = Uri.parse(resource).pathSegments.last;
        if (!RegExp(r'^baby_[A-Za-z0-9_-]+\.json\.enc\.ttl$').hasMatch(name)) {
          continue;
        }
        final content = await readPod('${BabyProfile.babiesDirectory}/$name');
        final baby = BabyProfile.tryParseJsonString(content);
        if (baby == null || baby.id.isEmpty) {
          throw FormatException('Invalid baby profile file: $name');
        }
        babies.add(baby);
      }
      return babies;
    } on ResourceNotExistException {
      return [];
    } catch (e) {
      debugPrint('loadBabies directory error: $e');
      rethrow;
    }
  }

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
          (e) => e.babyId.isEmpty ? e.copyWith(babyId: babyId) : e,
        )
        .toList();
    await writeAllLogEntries(migrated);
  }

  // ─── log entries — per-type storage ────────────────────────────────────────

  Future<List<LogEntry>> readAllLogEntries() async {
    final entries = <LogEntry>[];
    final seenIds = <String>{};

    // Read per-type files.
    for (final type in LogType.values) {
      try {
        final content = await readPod(LogEntry.fileNameForType(type));
        for (final e in LogEntry.listFromJsonString(content)) {
          if (seenIds.add(e.id)) entries.add(e);
        }
      } on ResourceNotExistException {
        // no entries of this type yet
      } catch (e) {
        debugPrint('readAllLogEntries(${type.name}) error: $e');
      }
    }

    // Migrate from legacy monolithic file if present.
    try {
      final content = await readPod(LogEntry.allEntriesFileName);
      final legacy = LogEntry.listFromJsonString(content);
      if (legacy.isNotEmpty) {
        await _migrateToPerTypeFiles(legacy);
        for (final e in legacy) {
          if (seenIds.add(e.id)) entries.add(e);
        }
      }
    } on ResourceNotExistException {
      // no legacy file
    } catch (e) {
      debugPrint('readAllLogEntries legacy error: $e');
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  Future<bool> writeLogEntry(LogEntry entry) async {
    try {
      final fileName = LogEntry.fileNameForType(entry.type);
      List<LogEntry> existing = [];
      try {
        final content = await readPod(fileName);
        existing = LogEntry.listFromJsonString(content);
      } on ResourceNotExistException {
        // first entry of this type
      }
      final updated = [entry, ...existing.where((e) => e.id != entry.id)];
      await writePod(
        fileName,
        LogEntry.listToJsonString(updated),
        encrypted: true,
        overwrite: true,
      );
      return true;
    } catch (e) {
      debugPrint('writeLogEntry error: $e');
      return false;
    }
  }

  Future<bool> updateLog(LogEntry entry) async {
    try {
      final fileName = LogEntry.fileNameForType(entry.type);
      final content = await readPod(fileName);
      final existing = LogEntry.listFromJsonString(content);
      final index = existing.indexWhere(
        (item) => item.id == entry.id && item.babyId == entry.babyId,
      );
      if (index == -1) return false;
      final updated = [...existing]..[index] = entry;
      await writePod(
        fileName,
        LogEntry.listToJsonString(updated),
        encrypted: true,
        overwrite: true,
      );
      return true;
    } catch (e) {
      debugPrint('updateLog error: $e');
      return false;
    }
  }

  Future<bool> writeAllLogEntries(List<LogEntry> entries) async {
    final byType = <LogType, List<LogEntry>>{};
    for (final e in entries) {
      byType.putIfAbsent(e.type, () => []).add(e);
    }
    var ok = true;
    for (final kv in byType.entries) {
      try {
        await writePod(
          LogEntry.fileNameForType(kv.key),
          LogEntry.listToJsonString(kv.value),
          encrypted: true,
          overwrite: true,
        );
      } catch (e) {
        debugPrint('writeAllLogEntries(${kv.key.name}) error: $e');
        ok = false;
      }
    }
    return ok;
  }

  Future<void> _migrateToPerTypeFiles(List<LogEntry> legacy) async {
    final byType = <LogType, List<LogEntry>>{};
    for (final e in legacy) {
      byType.putIfAbsent(e.type, () => []).add(e);
    }
    for (final kv in byType.entries) {
      try {
        await writePod(
          LogEntry.fileNameForType(kv.key),
          LogEntry.listToJsonString(kv.value),
          encrypted: true,
          overwrite: true,
        );
      } catch (e) {
        debugPrint('migrate(${kv.key.name}) error: $e');
      }
    }
    debugPrint('PodService: migrated ${legacy.length} entries to per-type files');
  }

  // ─── childcare entries ─────────────────────────────────────────────────────

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
