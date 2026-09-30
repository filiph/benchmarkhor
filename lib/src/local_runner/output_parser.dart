import 'package:logging/logging.dart';

/// Single parsed match found in the process stdout.
class BenchmarkParseMatch {
  final num duration;
  final String line;

  const BenchmarkParseMatch({required this.duration, required this.line});
}

/// Result of parsing benchmark output.
class BenchmarkParseResult {
  final num? durationUs;
  final int matchCount;
  final List<String> matchedLines;
  final List<String> warnings;

  const BenchmarkParseResult({
    required this.durationUs,
    required this.matchCount,
    required this.matchedLines,
    this.warnings = const [],
  });

  bool get hasDuration => durationUs != null;
}

/// Parser extracting `(RunTime): <num> us` metrics from stdout.
class BenchmarkOutputParser {
  static final RegExp runtimePattern = RegExp(
    r'\(RunTime\):\s*([0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\s*us',
  );

  final Logger _log;

  BenchmarkOutputParser({Logger? logger})
      : _log = logger ?? Logger('BenchmarkOutputParser');

  BenchmarkParseResult parse(String stdoutText) {
    final lines = stdoutText.split('\n');
    final matches = <BenchmarkParseMatch>[];

    for (final line in lines) {
      for (final match in runtimePattern.allMatches(line)) {
        final numStr = match.group(1);
        if (numStr != null) {
          final parsed = num.tryParse(numStr);
          if (parsed != null) {
            matches.add(BenchmarkParseMatch(duration: parsed, line: line));
          }
        }
      }
    }

    final warnings = <String>[];

    if (matches.isEmpty) {
      const msg = 'No line matching "(RunTime): ??? us" found in process stdout.';
      _log.severe(msg);
      warnings.add(msg);
      return const BenchmarkParseResult(
        durationUs: null,
        matchCount: 0,
        matchedLines: [],
        warnings: [msg],
      );
    }

    if (matches.length > 1) {
      final lastMatch = matches.last;
      final matchedLines = matches.map((m) => m.line).toList();
      final msg =
          'Found ${matches.length} matches for "(RunTime): ??? us" in stdout (expected 1). '
          'Selecting last match (${lastMatch.duration} us). Matched lines:\n'
          '${matchedLines.map((l) => '  $l').join('\n')}';
      _log.severe(msg);
      warnings.add(msg);
      return BenchmarkParseResult(
        durationUs: lastMatch.duration,
        matchCount: matches.length,
        matchedLines: matchedLines,
        warnings: warnings,
      );
    }

    // Exactly 1 match
    return BenchmarkParseResult(
      durationUs: matches.first.duration,
      matchCount: 1,
      matchedLines: [matches.first.line],
      warnings: const [],
    );
  }
}
