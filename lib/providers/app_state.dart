library;

import 'package:flutter/foundation.dart';

import 'package:seedpod/models/baby_profile.dart';
import 'package:seedpod/models/childcare_entry.dart';
import 'package:seedpod/models/log_entry.dart';
import 'package:seedpod/models/module_prefs.dart';
import 'package:seedpod/services/pod_service.dart';

enum LoadState { idle, loading, loaded, error }

/// Outcome of [AppState.importEntries].
class ImportResult {
  /// Number of new entries written.
  final int added;

  /// Number of incoming entries skipped because their id already existed.
  final int skipped;

  /// True if persisting the merged list to the POD failed.
  final bool failed;

  const ImportResult({
    required this.added,
    required this.skipped,
    this.failed = false,
  });
}

class AppState extends ChangeNotifier {
  final _pod = PodService();

  BabyProfile? _profile;
  List<LogEntry> _entries = [];
  List<ChildcareEntry> _childcareEntries = [];
  ModulePrefs _modulePrefs = ModulePrefs.defaults;
  LoadState _profileState = LoadState.idle;
  LoadState _entriesState = LoadState.idle;
  LoadState _childcareState = LoadState.idle;
  String? _error;

  BabyProfile? get profile => _profile;
  List<LogEntry> get entries => List.unmodifiable(_entries);
  List<ChildcareEntry> get childcareEntries => List.unmodifiable(_childcareEntries);
  ModulePrefs get modulePrefs => _modulePrefs;
  LoadState get profileState => _profileState;
  LoadState get entriesState => _entriesState;
  LoadState get childcareState => _childcareState;
  String? get error => _error;
  bool get hasProfile => _profile != null;

  Future<void> loadProfile() async {
    _profileState = LoadState.loading;
    notifyListeners();
    try {
      _profile = await _pod.readBabyProfile();
      _profileState = LoadState.loaded;
    } catch (e) {
      _error = e.toString();
      _profileState = LoadState.error;
    }
    notifyListeners();
  }

  Future<bool> saveProfile(BabyProfile profile) async {
    final ok = await _pod.writeBabyProfile(profile);
    if (ok) {
      _profile = profile;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> updateProfile(BabyProfile profile) async {
    final ok = await _pod.writeBabyProfile(profile);
    if (ok) {
      _profile = profile;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> deleteProfile() async {
    final ok = await _pod.deleteBabyProfile();
    if (ok) {
      _profile = null;
      notifyListeners();
    }
    return ok;
  }

  Future<void> loadEntries() async {
    _entriesState = LoadState.loading;
    notifyListeners();
    try {
      _entries = await _pod.readAllLogEntries();
      _entriesState = LoadState.loaded;
    } catch (e) {
      _error = e.toString();
      _entriesState = LoadState.error;
    }
    notifyListeners();
  }

  Future<bool> addEntry(LogEntry entry) async {
    final ok = await _pod.writeLogEntry(entry);
    if (ok) {
      _entries = [entry, ..._entries];
      notifyListeners();
    }
    return ok;
  }

  /// Result of an import: how many new entries were added, plus a failure flag.
  Future<ImportResult> importEntries(List<LogEntry> incoming) async {
    if (incoming.isEmpty) return const ImportResult(added: 0, skipped: 0);

    final existingIds = _entries.map((e) => e.id).toSet();
    final fresh = <LogEntry>[];
    var skipped = 0;
    for (final e in incoming) {
      if (existingIds.contains(e.id)) {
        skipped++;
      } else {
        existingIds.add(e.id);
        fresh.add(e);
      }
    }

    if (fresh.isEmpty) return ImportResult(added: 0, skipped: skipped);

    final merged = [...fresh, ..._entries]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final ok = await _pod.writeAllLogEntries(merged);
    if (!ok) return ImportResult(added: 0, skipped: skipped, failed: true);

    _entries = merged;
    notifyListeners();
    return ImportResult(added: fresh.length, skipped: skipped);
  }

  Future<void> loadModulePrefs() async {
    _modulePrefs = await ModulePrefs.loadFromPrefs();
    notifyListeners();
  }

  Future<void> toggleModule(String id) async {
    _modulePrefs = _modulePrefs.toggle(id);
    await _modulePrefs.saveToPrefs();
    notifyListeners();
  }

  Future<void> loadChildcareEntries() async {
    _childcareState = LoadState.loading;
    notifyListeners();
    try {
      _childcareEntries = await _pod.readChildcareEntries();
      _childcareState = LoadState.loaded;
    } catch (e) {
      _error = e.toString();
      _childcareState = LoadState.error;
    }
    notifyListeners();
  }

  Future<bool> saveChildcareEntries(List<ChildcareEntry> entries) async {
    final ok = await _pod.writeChildcareEntries(entries);
    if (ok) {
      _childcareEntries = entries;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> addChildcareEntry(ChildcareEntry entry) async {
    final updated = [entry, ..._childcareEntries];
    return saveChildcareEntries(updated);
  }

  Future<bool> updateChildcareEntry(ChildcareEntry entry) async {
    final updated = _childcareEntries
        .map((e) => e.id == entry.id ? entry : e)
        .toList();
    return saveChildcareEntries(updated);
  }

  Future<bool> deleteChildcareEntry(String id) async {
    final updated = _childcareEntries.where((e) => e.id != id).toList();
    return saveChildcareEntries(updated);
  }

  List<LogEntry> get todayEntries {
    final now = DateTime.now();
    return _entries.where((e) {
      return e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day;
    }).toList();
  }
}
