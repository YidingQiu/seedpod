library;

import 'dart:io';

/// Native (dart:io) implementation — writes bytes to the given filesystem path.
Future<void> writeBytesToPath(String path, List<int> bytes) async {
  await File(path).writeAsBytes(bytes, flush: true);
}
