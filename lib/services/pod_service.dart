library;

import 'package:flutter/foundation.dart';
import 'package:solidpod/solidpod.dart';

import 'package:seedpod/models/baby_profile.dart';
import 'package:seedpod/models/childcare_entry.dart';
import 'package:seedpod/models/log_entry.dart';

class PodService {
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
      final status = await checkResourceStatus(directoryUrl);
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
