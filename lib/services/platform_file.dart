library;

/// Writes [bytes] to [path] on platforms with a real filesystem.
///
/// Uses a conditional import so web builds (which have no `dart:io`) get the
/// stub no-op instead — on web, `FilePicker.saveFile(bytes: ...)` performs the
/// download directly, so nothing needs writing here.
export 'platform_file_stub.dart'
    if (dart.library.io) 'platform_file_io.dart';
