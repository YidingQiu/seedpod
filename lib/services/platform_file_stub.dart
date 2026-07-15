library;

/// Web stub — no filesystem, so this is a no-op. On web the browser download is
/// triggered by `FilePicker.saveFile(bytes: ...)` instead.
Future<void> writeBytesToPath(String path, List<int> bytes) async {}
