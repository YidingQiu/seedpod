library;

import 'package:flutter/foundation.dart';
import 'package:solidpod/solidpod.dart';

import 'package:seedpod/models/baby_profile.dart';
import 'package:seedpod/models/childcare_entry.dart';
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
      await writePod(
        LogEntry.allEntriesFileName,
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
