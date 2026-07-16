library;

import 'dart:convert';

import 'package:seedpod/models/log_entry.dart';

/// Import/export helpers for quick-log data.
///
/// Two interchangeable formats are supported:
///
///  * **JSON** — a single envelope holding every entry regardless of type
///    (see `schemas/quick_log_export.schema.json`).
///  * **CSV** — one table *per* [LogType], because each type has a different
///    set of columns (see `schemas/quick_log_csv.md`).
///
/// Both formats round-trip through `List<LogEntry>`, so converting between
/// them is just "parse one side, emit the other".

/// Bumped whenever the on-disk shape changes so future importers can migrate.
const String kQuickLogExportVersion = '1';

/// The CSV column schema. Every row is prefixed with `id,timestamp`; the lists
/// below are the type-specific `data.*` columns that follow, in order.
///
/// Keys mirror exactly what `QuickLogSheet._buildData` writes into
/// [LogEntry.data], so a CSV round-trip preserves the entry losslessly.
const Map<LogType, List<String>> kCsvDataColumns = {
  LogType.growth: ['weight_kg', 'height_cm', 'note'],
  LogType.sleep: ['start', 'end', 'note'],
  LogType.feeding: ['type', 'side', 'duration_min', 'amount_ml', 'note'],
  LogType.milestone: ['title', 'note'],
  LogType.health: ['title', 'note'],
  LogType.nappy: ['type', 'note'],
  LogType.medication: ['name', 'dose', 'note'],
  LogType.food: ['name', 'reaction', 'note'],
  LogType.teeth: ['tooth', 'note'],
  LogType.memory: ['title', 'note'],
  LogType.appointment: ['type', 'doctor', 'note'],
  LogType.sleep_training: ['method', 'note'],
  LogType.environment: ['title', 'note'],
  LogType.note: ['title', 'note'],
  LogType.photo: ['title', 'note'],
};

/// Thrown when input cannot be parsed into quick-log entries.
class QuickLogFormatException implements Exception {
  final String message;
  const QuickLogFormatException(this.message);
  @override
  String toString() => 'QuickLogFormatException: $message';
}

class QuickLogIo {
  QuickLogIo._();

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  /// Serialises [entries] into the pretty-printed JSON export envelope.
  static String exportJson(List<LogEntry> entries, {DateTime? exportedAt}) {
    final envelope = <String, dynamic>{
      'version': kQuickLogExportVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Parses a JSON export back into entries.
  ///
  /// Accepts either the full envelope (`{version, exportedAt, entries: [...]}`)
  /// or a bare array of entries, so hand-authored files also work.
  static List<LogEntry> importJson(String jsonString) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException catch (e) {
      throw QuickLogFormatException('Invalid JSON: ${e.message}');
    }

    final List<dynamic> rawEntries;
    if (decoded is Map && decoded['entries'] is List) {
      rawEntries = decoded['entries'] as List;
    } else if (decoded is List) {
      rawEntries = decoded;
    } else {
      throw const QuickLogFormatException(
        'Expected an object with an "entries" array, or a top-level array.',
      );
    }

    return rawEntries
        .whereType<Map>()
        .map((e) => LogEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // CSV (one table per type)
  // ---------------------------------------------------------------------------

  /// Full column order for [type]: `id, timestamp, <type-specific columns>`.
  static List<String> columnsFor(LogType type) => [
        'id',
        'timestamp',
        ...?kCsvDataColumns[type],
      ];

  /// Emits a CSV table for a single [type]. Entries of other types are ignored.
  static String exportCsv(LogType type, List<LogEntry> entries) {
    final dataCols = kCsvDataColumns[type] ?? const <String>[];
    final buffer = <String>[columnsFor(type).map(_escapeCsv).join(',')];

    for (final e in entries.where((e) => e.type == type)) {
      final cells = <String>[
        e.id,
        e.timestamp.toIso8601String(),
        for (final key in dataCols) e.data[key]?.toString() ?? '',
      ];
      buffer.add(cells.map(_escapeCsv).join(','));
    }
    return buffer.join('\r\n');
  }

  /// Parses a CSV table (as produced by [exportCsv]) back into entries of
  /// [type]. Data columns are read by *header name*, so column reordering and
  /// unknown extra columns are tolerated.
  static List<LogEntry> importCsv(LogType type, String csv) {
    final rows = _parseCsv(csv);
    if (rows.isEmpty) return const [];

    final header = rows.first;
    final idIdx = header.indexOf('id');
    final tsIdx = header.indexOf('timestamp');

    // Map each recognised data column to its position in the header.
    final knownKeys = kCsvDataColumns[type] ?? const <String>[];
    final dataIndex = <String, int>{};
    for (final key in knownKeys) {
      final at = header.indexOf(key);
      if (at != -1) dataIndex[key] = at;
    }

    final entries = <LogEntry>[];
    for (final row in rows.skip(1)) {
      if (row.every((c) => c.trim().isEmpty)) continue;

      String cell(int i) => (i >= 0 && i < row.length) ? row[i] : '';

      final data = <String, dynamic>{};
      dataIndex.forEach((key, i) {
        final value = cell(i);
        if (value.isNotEmpty) data[key] = value;
      });

      final id = cell(idIdx);
      final ts = cell(tsIdx);
      entries.add(
        LogEntry(
          id: id.isNotEmpty
              ? id
              : DateTime.now().microsecondsSinceEpoch.toString(),
          type: type,
          timestamp: DateTime.tryParse(ts) ?? DateTime.now(),
          data: data,
        ),
      );
    }
    return entries;
  }

  /// Splits a mixed list of entries into one CSV table per type, keyed by
  /// [LogType.name]. Types with no entries are omitted.
  static Map<String, String> exportAllCsv(List<LogEntry> entries) {
    final result = <String, String>{};
    for (final type in kCsvDataColumns.keys) {
      final ofType = entries.where((e) => e.type == type).toList();
      if (ofType.isEmpty) continue;
      result[type.name] = exportCsv(type, ofType);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // JSON <-> CSV bridges
  // ---------------------------------------------------------------------------

  /// JSON export → one CSV table per type (keyed by [LogType.name]).
  static Map<String, String> jsonToCsv(String jsonString) =>
      exportAllCsv(importJson(jsonString));

  /// A single-type CSV table → JSON export envelope.
  static String csvToJson(LogType type, String csv, {DateTime? exportedAt}) =>
      exportJson(importCsv(type, csv), exportedAt: exportedAt);

  // ---------------------------------------------------------------------------
  // CSV low-level helpers (RFC 4180)
  // ---------------------------------------------------------------------------

  /// Quotes a field if it contains a comma, quote, or line break, doubling any
  /// embedded quotes.
  static String _escapeCsv(String value) {
    final needsQuoting = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuoting) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// An RFC-4180 CSV reader. A field is treated as quoted only when a double
  /// quote is its *first* character; inside such a field `""` is a literal
  /// quote and the field ends at a `"` followed by a comma, a line ending, or
  /// end-of-input. In an unquoted field, double quotes are kept literally
  /// (so `he said "hi"` round-trips unchanged). Handles `\r\n` / `\n` / `\r`.
  static List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    if (input.isEmpty) return rows;

    final n = input.length;
    var row = <String>[];
    var i = 0;

    while (true) {
      // --- parse one field starting at i ---
      final field = StringBuffer();
      if (i < n && input[i] == '"') {
        // Quoted field: quote is the first character.
        i++; // consume opening quote
        while (i < n) {
          final ch = input[i];
          if (ch == '"') {
            if (i + 1 < n && input[i + 1] == '"') {
              field.write('"'); // escaped quote
              i += 2;
              continue;
            }
            final next = i + 1 < n ? input[i + 1] : '';
            if (next.isEmpty ||
                next == ',' ||
                next == '\n' ||
                next == '\r') {
              i++; // consume the closing quote
              break;
            }
            // A stray quote not followed by a delimiter: keep it literally.
            field.write('"');
            i++;
            continue;
          }
          field.write(ch);
          i++;
        }
      } else {
        // Unquoted field: quotes are ordinary characters.
        while (i < n) {
          final ch = input[i];
          if (ch == ',' || ch == '\n' || ch == '\r') break;
          field.write(ch);
          i++;
        }
      }
      row.add(field.toString());

      // --- handle the terminator (comma, line ending, or EOF) ---
      if (i >= n) {
        rows.add(row);
        break;
      }
      final term = input[i];
      if (term == ',') {
        i++;
        continue; // next field, same row
      }
      // line ending
      if (term == '\r' && i + 1 < n && input[i + 1] == '\n') i++;
      i++;
      rows.add(row);
      row = <String>[];
      if (i >= n) break; // trailing newline: no extra empty row
    }

    return rows;
  }
}
