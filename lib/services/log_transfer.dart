library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:seedpod/models/log_entry.dart';
import 'package:seedpod/models/log_io.dart';
import 'package:seedpod/providers/app_state.dart';
import 'package:seedpod/services/platform_file.dart';

/// File-dialog / share glue that connects [QuickLogIo] to the OS file pickers
/// and wires imports back into [AppState].
class LogTransfer {
  LogTransfer._();

  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Exports every entry as a single JSON file.
  static Future<void> exportJson(
    BuildContext context,
    List<LogEntry> entries,
  ) async {
    if (entries.isEmpty) {
      _snack(context, 'No log entries to export.');
      return;
    }
    final bytes = utf8.encode(QuickLogIo.exportJson(entries));
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Export logs as JSON',
        fileName: 'seedpod_logs.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(bytes),
      );
      if (path == null) return; // user cancelled
      if (_isDesktop) await writeBytesToPath(path, bytes);
      if (!context.mounted) return;
      _snack(context, 'Exported ${entries.length} entries to JSON.');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Export failed: $e', error: true);
    }
  }

  /// Exports one CSV file per log type. On desktop the user picks a folder; on
  /// mobile the files are shared via the OS share sheet.
  static Future<void> exportCsv(
    BuildContext context,
    List<LogEntry> entries,
  ) async {
    final tables = QuickLogIo.exportAllCsv(entries);
    if (tables.isEmpty) {
      _snack(context, 'No log entries to export.');
      return;
    }

    try {
      if (_isDesktop) {
        final dir = await FilePicker.getDirectoryPath(
          dialogTitle: 'Choose a folder for the CSV files',
        );
        if (dir == null) return; // cancelled
        for (final table in tables.entries) {
          await writeBytesToPath(
            '$dir/seedpod_${table.key}.csv',
            utf8.encode(table.value),
          );
        }
        if (!context.mounted) return;
        _snack(context, 'Exported ${tables.length} CSV file(s).');
      } else if (kIsWeb) {
        // Web has no folder picker; save each table as its own download.
        for (final table in tables.entries) {
          await FilePicker.saveFile(
            dialogTitle: 'Save ${table.key}.csv',
            fileName: 'seedpod_${table.key}.csv',
            type: FileType.custom,
            allowedExtensions: const ['csv'],
            bytes: Uint8List.fromList(utf8.encode(table.value)),
          );
        }
        if (!context.mounted) return;
        _snack(context, 'Exported ${tables.length} CSV file(s).');
      } else {
        // Mobile: write to a temp dir and hand off to the share sheet.
        final tmp = await getTemporaryDirectory();
        final files = <XFile>[];
        for (final table in tables.entries) {
          final path = '${tmp.path}/seedpod_${table.key}.csv';
          await writeBytesToPath(path, utf8.encode(table.value));
          files.add(XFile(path, mimeType: 'text/csv'));
        }
        await SharePlus.instance.share(
          ShareParams(files: files, subject: 'SeedPod logs (CSV)'),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Export failed: $e', error: true);
    }
  }

  /// Exports one CSV file per log type, bundled into a single .zip archive.
  static Future<void> exportCsvZip(
    BuildContext context,
    List<LogEntry> entries,
  ) async {
    final tables = QuickLogIo.exportAllCsv(entries);
    if (tables.isEmpty) {
      _snack(context, 'No log entries to export.');
      return;
    }
    try {
      final archive = Archive();
      for (final table in tables.entries) {
        archive.add(ArchiveFile.string('seedpod_${table.key}.csv', table.value));
      }
      final zipBytes = ZipEncoder().encode(archive);
      final path = await FilePicker.saveFile(
        dialogTitle: 'Export logs as zipped CSV',
        fileName: 'seedpod_logs_csv.zip',
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        bytes: Uint8List.fromList(zipBytes),
      );
      if (path == null) return; // cancelled
      if (_isDesktop) await writeBytesToPath(path, zipBytes);
      if (!context.mounted) return;
      _snack(context, 'Exported ${tables.length} CSV file(s) as a zip.');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Export failed: $e', error: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Imports entries from a JSON export and merges them into the POD.
  static Future<void> importJson(BuildContext context, AppState state) async {
    final text = await _pickTextFile(context, 'json', 'Import logs from JSON');
    if (text == null) return;
    try {
      final entries = QuickLogIo.importJson(text);
      final result = await state.importEntries(entries);
      if (context.mounted) _snackResult(context, result);
    } on QuickLogFormatException catch (e) {
      if (context.mounted) _snack(context, e.message, error: true);
    }
  }

  /// Imports a single-type CSV table. The type is guessed from the filename and
  /// confirmed by the user.
  static Future<void> importCsv(BuildContext context, AppState state) async {
    final picked =
        await _pickTextFileNamed(context, 'csv', 'Import logs from CSV');
    if (picked == null) return;
    final (name, text) = picked;

    if (!context.mounted) return;
    final type = await _promptType(context, _guessType(name));
    if (type == null) return;

    try {
      final entries = QuickLogIo.importCsv(type, text);
      final result = await state.importEntries(entries);
      if (context.mounted) _snackResult(context, result);
    } on QuickLogFormatException catch (e) {
      if (context.mounted) _snack(context, e.message, error: true);
    }
  }

  /// Imports a .zip of CSV files (as produced by [exportCsvZip]). Each CSV's
  /// log type is confirmed by the user one file at a time (pre-selecting a
  /// guess from the filename); a file can be skipped from its dialog.
  static Future<void> importCsvZip(BuildContext context, AppState state) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import zipped CSV logs',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) {
      if (context.mounted) {
        _snack(context, 'Could not read the selected file.', error: true);
      }
      return;
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Not a valid .zip file: $e', error: true);
      }
      return;
    }

    final csvFiles = archive
        .where((f) => f.isFile && f.name.toLowerCase().endsWith('.csv'))
        .toList();
    if (csvFiles.isEmpty) {
      if (context.mounted) {
        _snack(context, 'No .csv files found in the zip.', error: true);
      }
      return;
    }

    final all = <LogEntry>[];
    var skipped = 0;
    for (final file in csvFiles) {
      if (!context.mounted) return;
      final type = await _promptType(
        context,
        _guessType(file.name),
        fileName: _baseName(file.name),
      );
      if (type == null) {
        skipped++;
        continue; // user skipped this file
      }
      try {
        all.addAll(QuickLogIo.importCsv(type, utf8.decode(file.content)));
      } on QuickLogFormatException {
        skipped++;
      }
    }

    if (all.isEmpty) {
      if (context.mounted) {
        _snack(context, 'No files imported from the zip.');
      }
      return;
    }
    final res = await state.importEntries(all);
    if (context.mounted) _snackResult(context, res, skippedFiles: skipped);
  }

  static String _baseName(String path) =>
      path.split(RegExp(r'[/\\]')).last;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Future<String?> _pickTextFile(
    BuildContext context,
    String extension,
    String title,
  ) async {
    final named = await _pickTextFileNamed(context, extension, title);
    return named?.$2;
  }

  static Future<(String, String)?> _pickTextFileNamed(
    BuildContext context,
    String extension,
    String title,
  ) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: title,
      type: FileType.custom,
      allowedExtensions: [extension],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (context.mounted) {
        _snack(context, 'Could not read the selected file.', error: true);
      }
      return null;
    }
    try {
      return (file.name, utf8.decode(bytes));
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'File is not valid UTF-8 text.', error: true);
      }
      return null;
    }
  }

  /// Guesses a log type from a filename like `seedpod_growth.csv`. Longer type
  /// names are tried first so e.g. `sleep_training` wins over `sleep`.
  static LogType? _guessType(String fileName) {
    final lower = fileName.toLowerCase();
    final types = kCsvDataColumns.keys.toList()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    for (final type in types) {
      if (lower.contains(type.name)) return type;
    }
    return null;
  }

  /// Asks which log type a CSV file belongs to. Returns null if dismissed or
  /// skipped. When [fileName] is given it is shown in the title.
  static Future<LogType?> _promptType(
    BuildContext context,
    LogType? initial, {
    String? fileName,
  }) {
    return showDialog<LogType>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text(
            fileName == null
                ? 'Which log type is this CSV?'
                : 'What does "$fileName" contain?',
          ),
          children: [
            for (final type in kCsvDataColumns.keys)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(type),
                child: Row(
                  children: [
                    if (type == initial)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.check, size: 18),
                      ),
                    Text(type.label),
                  ],
                ),
              ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Skip this file'),
            ),
          ],
        );
      },
    );
  }

  static void _snackResult(
    BuildContext context,
    ImportResult result, {
    int skippedFiles = 0,
  }) {
    final fileNote =
        skippedFiles > 0 ? ' ($skippedFiles file(s) skipped)' : '';
    if (result.failed) {
      _snack(context, 'Import failed while saving to your POD.', error: true);
      return;
    }
    if (result.added == 0) {
      _snack(
        context,
        result.skipped > 0
            ? 'Nothing new — ${result.skipped} entr'
                '${result.skipped == 1 ? 'y' : 'ies'} already existed.$fileNote'
            : 'No entries found to import.$fileNote',
      );
      return;
    }
    final skippedNote =
        result.skipped > 0 ? ' (${result.skipped} duplicate(s) skipped)' : '';
    _snack(
      context,
      'Imported ${result.added} entr'
      '${result.added == 1 ? 'y' : 'ies'}$skippedNote.$fileNote',
    );
  }

  static void _snack(
    BuildContext context,
    String message, {
    bool error = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }
}
