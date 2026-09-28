import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Records raw iteration measurements for pure-Dart benchmarks and manages
/// the completion sentinels (`DONE` / `FAILED`) expected by `adb_server`.
///
/// In accordance with ADR 0002 and ADR 0005, the device records unaggregated
/// raw events into `iterations.jsonl`. Host-side analysis tools (`extract_dat.dart`)
/// are responsible for statistical aggregation.
class BenchmarkRecorder {
  /// The directory where measurement files and sentinel markers are written.
  final Directory outputDir;

  /// The output filename for raw iteration records, defaults to `iterations.jsonl`.
  final String filename;

  late final File _file;
  late final IOSink _sink;
  int _iterationCount = 0;
  bool _isClosed = false;

  /// Returns the number of iterations recorded so far.
  int get iterationCount => _iterationCount;

  /// Whether the recorder sink has been closed.
  bool get isClosed => _isClosed;

  BenchmarkRecorder({
    required this.outputDir,
    this.filename = 'iterations.jsonl',
  }) {
    outputDir.createSync(recursive: true);
    _file = File(p.join(outputDir.path, filename));
    _sink = _file.openWrite(mode: FileMode.append);
  }

  /// Resolves the canonical on-device result directory for an Android package.
  ///
  /// Typically `/sdcard/Android/data/<package>/files`.
  static Directory defaultDeviceResultDir(String package) {
    return Directory('/sdcard/Android/data/$package/files');
  }

  /// Appends a single iteration record with the elapsed time in microseconds.
  ///
  /// If [iteration] is omitted, an auto-incrementing 1-based index is used.
  /// If [timestampUs] is omitted, the current wall-clock epoch in microseconds is used.
  void recordIteration({
    required int durationUs,
    int? iteration,
    int? timestampUs,
  }) {
    if (_isClosed) {
      throw StateError('Cannot record iteration on a closed BenchmarkRecorder.');
    }
    _iterationCount++;
    final iter = iteration ?? _iterationCount;
    final ts = timestampUs ?? DateTime.now().microsecondsSinceEpoch;

    final record = {
      'iteration': iter,
      'durationUs': durationUs,
      'timestampUs': ts,
    };
    _sink.writeln(jsonEncode(record));
  }

  /// Synchronously executes [action], measures its elapsed microseconds,
  /// records the iteration, and returns the result.
  T measure<T>(T Function() action) {
    final sw = Stopwatch()..start();
    try {
      return action();
    } finally {
      sw.stop();
      recordIteration(durationUs: sw.elapsedMicroseconds);
    }
  }

  /// Asynchronously executes [action], measures its elapsed microseconds,
  /// records the iteration, and returns the result.
  Future<T> measureAsync<T>(Future<T> Function() action) async {
    final sw = Stopwatch()..start();
    try {
      return await action();
    } finally {
      sw.stop();
      recordIteration(durationUs: sw.elapsedMicroseconds);
    }
  }

  /// Flushes any buffered records to disk.
  Future<void> flush() async {
    if (!_isClosed) {
      await _sink.flush();
    }
  }

  /// Flushes and closes the JSONL file.
  Future<void> close() async {
    if (!_isClosed) {
      await _sink.flush();
      await _sink.close();
      _isClosed = true;
    }
  }

  /// Signals successful benchmark completion according to the runner contract:
  ///
  /// 1. Flushes and closes `iterations.jsonl`.
  /// 2. Creates the `DONE` sentinel file in [outputDir].
  /// 3. Emits `BENCH_DONE` to stdout/logcat for adb monitoring.
  Future<void> complete({int exitCode = 0}) async {
    await close();
    final doneFile = File(p.join(outputDir.path, 'DONE'));
    await doneFile.writeAsString('');
    // Printed to logcat on Android
    print('BENCH_DONE $exitCode ${outputDir.path} $_iterationCount iterations');
  }

  /// Signals benchmark failure according to the runner contract:
  ///
  /// 1. Flushes and closes `iterations.jsonl`.
  /// 2. Creates the `FAILED` sentinel file containing [reason] in [outputDir].
  /// 3. Emits `BENCH_FAILED` to stdout/logcat for adb monitoring.
  Future<void> fail(String reason) async {
    await close();
    final failedFile = File(p.join(outputDir.path, 'FAILED'));
    await failedFile.writeAsString(reason);
    // Printed to logcat on Android
    print('BENCH_FAILED $reason');
  }
}
