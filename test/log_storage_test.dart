import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:seedpod/models/log_entry.dart';
import 'package:seedpod/models/log_io.dart';

// ─── helpers ──────────────────────────────────────────────────────────────────

LogEntry _entry(LogType type, {String id = 'id1', String babyId = 'b1'}) =>
    LogEntry(
      id: id,
      babyId: babyId,
      type: type,
      timestamp: DateTime(2026, 7, 16, 10),
      data: const {'title': 'test'},
    );

// ─── per-type file name routing ───────────────────────────────────────────────

void _fileNameTests() {
  group('LogEntry.fileNameForType', () {
    test('all types resolve to logs/<name>.json.enc.ttl', () {
      for (final type in LogType.values) {
        final name = LogEntry.fileNameForType(type);
        expect(name, 'logs/${type.name}.json.enc.ttl',
            reason: 'type $type has unexpected path');
      }
    });

    test('no two types share the same file name', () {
      final names = LogType.values.map(LogEntry.fileNameForType).toList();
      expect(names.toSet().length, equals(names.length),
          reason: 'duplicate per-type file names detected');
    });

    test('legacy file name is distinct from all per-type names', () {
      final perType = LogType.values.map(LogEntry.fileNameForType).toSet();
      expect(perType, isNot(contains(LogEntry.allEntriesFileName)));
    });
  });
}

// ─── serialization round-trip ─────────────────────────────────────────────────

void _serializationTests() {
  group('LogEntry serialization', () {
    test('single entry survives fromJson/toJson', () {
      final e = _entry(LogType.feeding,
          id: '123', babyId: 'baby42');
      final json = e.toJson();
      final decoded = LogEntry.fromJson(json);
      expect(decoded.id, e.id);
      expect(decoded.babyId, e.babyId);
      expect(decoded.type, e.type);
      expect(decoded.timestamp.toIso8601String(),
          e.timestamp.toIso8601String());
      expect(decoded.data, e.data);
    });

    test('unknown type falls back to LogType.note', () {
      final raw = <String, dynamic>{
        'id': 'x',
        'babyId': 'b',
        'type': 'totally_unknown_type',
        'timestamp': '2026-07-16T00:00:00.000',
        'data': <String, dynamic>{},
      };
      final e = LogEntry.fromJson(raw);
      expect(e.type, LogType.note);
    });

    test('listFromJsonString / listToJsonString round-trip', () {
      final entries = LogType.values
          .take(5)
          .indexed
          .map((iv) => _entry(iv.$2, id: 'e${iv.$1}'))
          .toList();

      final json = LogEntry.listToJsonString(entries);
      final decoded = LogEntry.listFromJsonString(json);

      expect(decoded.length, entries.length);
      for (var i = 0; i < entries.length; i++) {
        expect(decoded[i].id, entries[i].id);
        expect(decoded[i].type, entries[i].type);
      }
    });

    test('listFromJsonString returns empty on malformed input', () {
      expect(LogEntry.listFromJsonString(''), isEmpty);
      expect(LogEntry.listFromJsonString('not json'), isEmpty);
      expect(LogEntry.listFromJsonString('{}'), isEmpty);
    });
  });
}

// ─── deduplication (mirrors readAllLogEntries logic) ─────────────────────────

void _deduplicationTests() {
  group('deduplication by id', () {
    test('duplicate ids from two sources are collapsed', () {
      // Simulate merging per-type and legacy entries with overlapping ids.
      final perType = [
        _entry(LogType.feeding, id: 'dup'),
        _entry(LogType.sleep, id: 'unique'),
      ];
      final legacy = [
        _entry(LogType.feeding, id: 'dup'), // same id — should be dropped
        _entry(LogType.growth, id: 'legacy_only'),
      ];

      final all = [...perType, ...legacy];
      final seenIds = <String>{};
      final merged =
          all.where((e) => seenIds.add(e.id)).toList();

      expect(merged.length, 3); // dup, unique, legacy_only
      expect(merged.map((e) => e.id).toSet(),
          containsAll(['dup', 'unique', 'legacy_only']));
    });
  });
}

// ─── migration grouping logic ─────────────────────────────────────────────────

void _migrationGroupingTests() {
  group('migration grouping (byType)', () {
    test('entries are partitioned into per-type groups', () {
      final entries = [
        _entry(LogType.feeding, id: 'f1'),
        _entry(LogType.feeding, id: 'f2'),
        _entry(LogType.sleep, id: 's1'),
        _entry(LogType.growth, id: 'g1'),
      ];

      final byType = <LogType, List<LogEntry>>{};
      for (final e in entries) {
        byType.putIfAbsent(e.type, () => []).add(e);
      }

      expect(byType.keys, containsAll([LogType.feeding, LogType.sleep, LogType.growth]));
      expect(byType[LogType.feeding]!.length, 2);
      expect(byType[LogType.sleep]!.length, 1);
      expect(byType[LogType.growth]!.length, 1);
    });

    test('per-type group files match fileNameForType', () {
      final types = [LogType.feeding, LogType.sleep, LogType.growth];
      final byType = {for (final t in types) t: <LogEntry>[]};

      for (final kv in byType.entries) {
        final expectedFile = LogEntry.fileNameForType(kv.key);
        expect(expectedFile, startsWith('logs/'));
        expect(expectedFile, endsWith('.json.enc.ttl'));
      }
    });

    test('round-trip through listToJsonString preserves all entries per type', () {
      final feeding = [
        _entry(LogType.feeding, id: 'f1'),
        _entry(LogType.feeding, id: 'f2'),
      ];
      final encoded = LogEntry.listToJsonString(feeding);
      final decoded = LogEntry.listFromJsonString(encoded);
      expect(decoded.length, 2);
      expect(decoded.every((e) => e.type == LogType.feeding), isTrue);
    });
  });
}

// ─── QuickLogIo JSON round-trip ────────────────────────────────────────────────

void _quickLogIoTests() {
  group('QuickLogIo JSON', () {
    test('exportJson / importJson round-trip', () {
      final entries = [
        _entry(LogType.feeding, id: 'f1'),
        _entry(LogType.sleep, id: 's1'),
      ];
      final json = QuickLogIo.exportJson(entries);
      final decoded = QuickLogIo.importJson(json);
      expect(decoded.length, 2);
      expect(decoded.map((e) => e.id), containsAll(['f1', 's1']));
    });

    test('exportJson output has version field', () {
      final json = QuickLogIo.exportJson([_entry(LogType.feeding)]);
      final map = jsonDecode(json) as Map;
      expect(map['version'], isNotNull);
      expect(map['entries'], isA<List>());
    });

    test('importJson accepts bare array (no envelope)', () {
      final bare = jsonEncode([_entry(LogType.sleep).toJson()]);
      final decoded = QuickLogIo.importJson(bare);
      expect(decoded.length, 1);
      expect(decoded.first.type, LogType.sleep);
    });

    test('importJson throws on invalid JSON', () {
      expect(() => QuickLogIo.importJson('bad json'),
          throwsA(isA<QuickLogFormatException>()));
    });

    test('importJson throws on unexpected JSON shape', () {
      expect(() => QuickLogIo.importJson('"just a string"'),
          throwsA(isA<QuickLogFormatException>()));
    });
  });
}

// ─── writeLogEntry idempotency (no POD, pure logic) ──────────────────────────

void _idempotencyTests() {
  group('writeLogEntry idempotency contract', () {
    test('inserting same id twice keeps only one copy', () {
      final existing = [_entry(LogType.feeding, id: 'dup')];
      final newEntry = _entry(LogType.feeding, id: 'dup');

      // Mirrors pod_service.writeLogEntry filter:
      final updated = [newEntry, ...existing.where((e) => e.id != newEntry.id)];

      expect(updated.length, 1);
      expect(updated.first.id, 'dup');
    });
  });
}

// ─── main ─────────────────────────────────────────────────────────────────────

void main() {
  _fileNameTests();
  _serializationTests();
  _deduplicationTests();
  _migrationGroupingTests();
  _quickLogIoTests();
  _idempotencyTests();
}
