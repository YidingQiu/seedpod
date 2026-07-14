library;

import 'package:flutter/foundation.dart';

import 'package:seedpod/models/baby_profile.dart';
import 'package:seedpod/models/log_entry.dart';
import 'package:seedpod/services/pod_service.dart';

enum LoadState { idle, loading, loaded, error }

class AppState extends ChangeNotifier {
  final _pod = PodService();

  BabyProfile? _profile;
  List<LogEntry> _entries = [];
  LoadState _profileState = LoadState.idle;
  LoadState _entriesState = LoadState.idle;
  String? _error;

  BabyProfile? get profile => _profile;
  List<LogEntry> get entries => List.unmodifiable(_entries);
  LoadState get profileState => _profileState;
  LoadState get entriesState => _entriesState;
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

  List<LogEntry> get todayEntries {
    final now = DateTime.now();
    return _entries
        .where(
          (e) =>
              e.timestamp.year == now.year &&
              e.timestamp.month == now.month &&
              e.timestamp.day == now.day,
        )
        .toList();
  }
}
