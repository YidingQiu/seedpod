library;

import 'package:flutter/material.dart';

import 'package:seedpod/models/log_entry.dart';

/// Bridges a module (see [ModulePrefs.allModules]) to its quick-loggable
/// [LogType], icon and label. Used by both the home Quick Actions and the
/// Quick Log sheet so they stay in sync with the enabled modules.
class LogTypeOption {
  final LogType type;
  final IconData icon;
  final String label;
  final String moduleId;

  const LogTypeOption(this.type, this.icon, this.label, this.moduleId);
}

const List<LogTypeOption> logTypeOptions = [
  // Core
  LogTypeOption(LogType.growth, Icons.straighten, 'Growth', 'growth'),
  LogTypeOption(LogType.sleep, Icons.bedtime, 'Sleep', 'sleep'),
  LogTypeOption(LogType.feeding, Icons.local_cafe, 'Feeding', 'feeding'),
  LogTypeOption(LogType.milestone, Icons.star, 'Milestone', 'milestone'),
  // Optional
  LogTypeOption(LogType.nappy, Icons.baby_changing_station, 'Nappy', 'nappy'),
  LogTypeOption(LogType.food, Icons.restaurant, 'Food', 'food'),
  LogTypeOption(LogType.medication, Icons.medication, 'Meds', 'medication'),
  LogTypeOption(
      LogType.appointment, Icons.local_hospital, 'Doctor', 'appointment',),
  LogTypeOption(LogType.health, Icons.favorite, 'Health', 'health'),
  LogTypeOption(LogType.teeth, Icons.mood, 'Teeth', 'teeth'),
  LogTypeOption(LogType.memory, Icons.auto_stories, 'Memory', 'memory'),
  LogTypeOption(
      LogType.sleep_training, Icons.nightlight, 'Sleep Trng', 'sleep_training',),
  LogTypeOption(LogType.environment, Icons.wb_sunny, 'Weather', 'environment'),
  LogTypeOption(LogType.note, Icons.edit_note, 'Note', 'milestone'),
];
