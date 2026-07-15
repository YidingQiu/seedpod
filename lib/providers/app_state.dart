library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seedpod/models/baby_profile.dart';
import 'package:seedpod/models/childcare_entry.dart';
import 'package:seedpod/models/log_entry.dart';
import 'package:seedpod/models/module_prefs.dart';
import 'package:seedpod/models/vaccine_reminder.dart';
import 'package:seedpod/services/pod_service.dart';

enum LoadState { idle, loading, loaded, error }

class ImportResult {
  final int added;
  final int skipped;
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
  final Map<String, String> _vaccineDoneDates = {};
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
  bool get vaccineCompletionsLoaded => _vaccineCompletionsLoaded;
  bool _vaccineCompletionsLoaded = false;

  List<VaccineReminder> get vaccineReminders {
    final baby = selectedBaby;
    if (baby == null || !_vaccineCompletionsLoaded) return [];
    return deriveVaccineReminders(
      baby: baby,
      completedVaccineIds: _completedVaccineIds(baby.id),
    );
  }

  Future<void> loadProfile() async {
    _profileState = LoadState.loading;
    notifyListeners();
    try {
      _babies = await _pod.loadBabies();
      if (!_babies.any((baby) => baby.id == _selectedBabyId)) {
        _selectedBabyId = _babies.firstOrNull?.id;
      }
      await _loadVaccineCompletions();
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

  bool isVaccineDone(String vaccineId, {String? babyId}) {
    final id = babyId ?? _selectedBabyId;
    return id != null &&
        _vaccineDoneDates.containsKey(_vaccineMapKey(id, vaccineId));
  }

  String? vaccineDoneDate(String vaccineId, {String? babyId}) {
    final id = babyId ?? _selectedBabyId;
    return id == null ? null : _vaccineDoneDates[_vaccineMapKey(id, vaccineId)];
  }

  Future<void> setVaccineDone(String vaccineId, bool done) async {
    final babyId = _selectedBabyId;
    if (babyId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final storageKey = _vaccineStorageKey(babyId, vaccineId);
    final mapKey = _vaccineMapKey(babyId, vaccineId);
    if (done) {
      final date = DateTime.now().toIso8601String();
      await prefs.setString(storageKey, date);
      _vaccineDoneDates[mapKey] = date;
    } else {
      await prefs.remove(storageKey);
      _vaccineDoneDates.remove(mapKey);
    }
    notifyListeners();
  }

  Future<void> _loadVaccineCompletions() async {
    final prefs = await SharedPreferences.getInstance();
    _vaccineDoneDates.clear();
    for (final baby in _babies) {
      for (var mIdx = 0; mIdx < actVaccineSchedule.length; mIdx++) {
        for (var vIdx = 0;
            vIdx < actVaccineSchedule[mIdx].vaccines.length;
            vIdx++) {
          final id = vaccineId(mIdx, vIdx);
          final value = prefs.getString(_vaccineStorageKey(baby.id, id));
          if (value != null) {
            _vaccineDoneDates[_vaccineMapKey(baby.id, id)] = value;
          }
        }
      }
    }

    const migrationMarker = 'vax_legacy_migrated_baby_id';
    final migrationBaby = selectedBaby;
    if (migrationBaby != null && prefs.getString(migrationMarker) == null) {
      for (var mIdx = 0; mIdx < actVaccineSchedule.length; mIdx++) {
        for (var vIdx = 0;
            vIdx < actVaccineSchedule[mIdx].vaccines.length;
            vIdx++) {
          final id = vaccineId(mIdx, vIdx);
          final legacyValue = prefs.getString('vax_$id');
          if (legacyValue == null) continue;
          await prefs.setString(
            _vaccineStorageKey(migrationBaby.id, id),
            legacyValue,
          );
          _vaccineDoneDates[_vaccineMapKey(migrationBaby.id, id)] = legacyValue;
        }
      }
      await prefs.setString(migrationMarker, migrationBaby.id);
    }
    _vaccineCompletionsLoaded = true;
  }

  Set<String> _completedVaccineIds(String babyId) {
    final prefix = '$babyId::';
    return _vaccineDoneDates.keys
        .where((key) => key.startsWith(prefix))
        .map((key) => key.substring(prefix.length))
        .toSet();
  }

  String _vaccineMapKey(String babyId, String vaccineId) =>
      '$babyId::$vaccineId';

  String _vaccineStorageKey(String babyId, String vaccineId) =>
      'vax_${babyId}_$vaccineId';

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

  Future<ImportResult> importEntries(List<LogEntry> importedEntries) async {
    final baby = selectedBaby;
    if (baby == null) {
      return ImportResult(
        added: 0,
        skipped: importedEntries.length,
        failed: true,
      );
    }

    final knownIds = _entries
        .where((entry) => entry.babyId == baby.id)
        .map((entry) => entry.id)
        .toSet();
    final additions = <LogEntry>[];
    var skipped = 0;
    for (final entry in importedEntries) {
      if (!knownIds.add(entry.id)) {
        skipped++;
        continue;
      }
      additions.add(entry.copyWith(babyId: baby.id));
    }

    if (additions.isEmpty) {
      return ImportResult(added: 0, skipped: skipped);
    }

    final updated = [...additions, ..._entries]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final ok = await _pod.writeAllLogEntries(updated);
    if (!ok) {
      return ImportResult(added: 0, skipped: skipped, failed: true);
    }

    _entries = updated;
    notifyListeners();
    return ImportResult(added: additions.length, skipped: skipped);
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
