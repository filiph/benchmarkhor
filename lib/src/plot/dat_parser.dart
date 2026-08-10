import 'dart:io';

/// Parse a .dat file: one number per line; non-number lines are ignored.
List<num> parseDat(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('File not found: $path');
    exit(1);
  }
  final values = <num>[];
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    final parsed = num.tryParse(trimmed);
    if (parsed != null) values.add(parsed);
  }
  return values;
}
