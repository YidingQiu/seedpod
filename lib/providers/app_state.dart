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

  List<BabyProfile> _babies = [];
  String? _selectedBabyId;
  List<LogEntry> _entries = [];
  List<ChildcareEntry> _childcareEntries = [];
  ModulePrefs _modulePrefs = ModulePrefs.defaults;
  LoadState _profileState = LoadState.idle;
  LoadState _entriesState = LoadState.idle;
  LoadState _childcareState = LoadState.idle;
  String? _error;

  List<BabyProfile> get babies => List.unmodifiable(_babies);
  String? get selectedBabyId => _selectedBabyId;
  BabyProfile? get selectedBaby {
    for (final baby in _babies) {
      if (baby.id == _selectedBabyId) return baby;
    }
    return null;
  }

  List<LogEntry> get entries => List.unmodifiable(
        _entries.where((entry) => entry.babyId == _selectedBabyId),
      );
  List<ChildcareEntry> get childcareEntries =>
      List.unmodifiable(_childcareEntries);
  ModulePrefs get modulePrefs => _modulePrefs;
  LoadState get profileState => _profileState;
  LoadState get entriesState => _entriesState;
  LoadState get childcareState => _childcareState;
  String? get error => _error;
  bool get hasBabies => _babies.isNotEmpty;

  Future<void> loadProfile() async {
    _profileState = LoadState.loading;
    notifyListeners();
    try {
      _babies = await _pod.loadBabies();
      if (!_babies.any((baby) => baby.id == _selectedBabyId)) {
        _selectedBabyId = _babies.firstOrNull?.id;
      }
      _profileState = LoadState.loaded;
    } catch (e) {
      _error = e.toString();
      _profileState = LoadState.error;
    }
    notifyListeners();
  }

  Future<bool> addBaby(BabyProfile baby) async {
    try {
      await _pod.createBaby(baby);
      _babies = [..._babies, baby];
      _selectedBabyId = baby.id;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  void selectBaby(String babyId) {
    if (!_babies.any((baby) => baby.id == babyId)) return;
    _selectedBabyId = babyId;
    notifyListeners();
  }

  Future<bool> updateBaby(BabyProfile baby) async {
    try {
      await _pod.updateBaby(baby);
      _babies =
          _babies.map((item) => item.id == baby.id ? baby : item).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> deleteBaby(String babyId) async {
    try {
      await _pod.deleteBaby(babyId);
      _babies = _babies.where((baby) => baby.id != babyId).toList();
      if (_selectedBabyId == babyId) {
        _selectedBabyId = _babies.firstOrNull?.id;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
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
    final baby = selectedBaby;
    if (baby == null) return false;
    final scopedEntry = entry.copyWith(babyId: baby.id);
    final ok = await _pod.writeLogEntry(scopedEntry);
    if (ok) {
      _entries = [scopedEntry, ..._entries];
      notifyListeners();
    }
    return ok;
  }

  /// Imports entries into the selected baby, skipping ids that already exist.
  Future<ImportResult> importEntries(List<LogEntry> incoming) async {
    final baby = selectedBaby;
    if (baby == null) {
      return const ImportResult(added: 0, skipped: 0, failed: true);
    }
    if (incoming.isEmpty) return const ImportResult(added: 0, skipped: 0);

    // Scope every imported entry to the currently selected baby.
    final scoped = incoming.map((e) => e.copyWith(babyId: baby.id)).toList();

    final existingIds = _entries
        .where((e) => e.babyId == baby.id)
        .map((e) => e.id)
        .toSet();
    final fresh = <LogEntry>[];
    var skipped = 0;
    for (final e in scoped) {
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

  Future<bool> updateEntry(LogEntry updatedEntry) async {
    final baby = selectedBaby;
    if (baby == null || updatedEntry.babyId != baby.id) return false;

    final index = _entries.indexWhere(
      (entry) =>
          entry.id == updatedEntry.id && entry.babyId == updatedEntry.babyId,
    );
    if (index == -1) return false;
    final original = _entries[index];
    if (original.babyId != baby.id || original.type != updatedEntry.type) {
      return false;
    }

    final safeUpdate = LogEntry(
      id: original.id,
      babyId: original.babyId,
      type: original.type,
      timestamp: updatedEntry.timestamp,
      data: updatedEntry.data,
    );
    final ok = await _pod.updateLog(safeUpdate);
    if (!ok) return false;

    _entries = [..._entries]..[index] = safeUpdate;
    _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
    return true;
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
    final updated =
        _childcareEntries.map((e) => e.id == entry.id ? entry : e).toList();
    return saveChildcareEntries(updated);
  }

  Future<bool> deleteChildcareEntry(String id) async {
    final updated = _childcareEntries.where((e) => e.id != id).toList();
    return saveChildcareEntries(updated);
  }

  List<LogEntry> get todayEntries {
    final now = DateTime.now();
    return entries.where((e) {
      return e.timestamp.year == now.year &&
          e.timestamp.month == now.month &&
          e.timestamp.day == now.day;
    }).toList();
  }
}
