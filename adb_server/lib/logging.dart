import 'dart:io';

const defaultMaxFiles = 5;

/// A simple rotating file logger that keeps a fixed number of log files.
/// When the current log file exceeds [maxFileSize], it is rotated:
/// server.log -> server.log.1
/// server.log.1 -> server.log.2
/// ...
/// server.log.(maxFiles-1) is deleted.
class RotatingFileLogger {
  final String path;
  final int maxFileSize;
  final int maxFiles;

  RotatingFileLogger(
    this.path, {
    this.maxFileSize = 1 * 1024 * 1024,
    this.maxFiles = defaultMaxFiles,
  });

  void log(String message) {
    try {
      final file = File(path);
      if (file.existsSync() && file.lengthSync() >= maxFileSize) {
        _rotate();
      }
      file.writeAsStringSync('$message\n', mode: FileMode.append, flush: true);
    } catch (e) {
      // If logging to file fails, we at least tried.
      // We don't want to crash the server because of logging issues.
      stderr.writeln('Failed to write to log file: $e');
    }
  }

  void _rotate() {
    try {
      for (var i = maxFiles - 1; i >= 1; i--) {
        final oldFile = File('$path.$i');
        if (oldFile.existsSync()) {
          if (i == maxFiles - 1) {
            oldFile.deleteSync();
          } else {
            final nextFile = '$path.${i + 1}';
            oldFile.renameSync(nextFile);
          }
        }
      }
      final current = File(path);
      if (current.existsSync()) {
        current.renameSync('$path.1');
      }
    } catch (e) {
      stderr.writeln('Failed to rotate log files: $e');
    }
  }
}
