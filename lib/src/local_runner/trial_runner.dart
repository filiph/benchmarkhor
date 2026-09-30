import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'host_probe.dart';
import 'models.dart';
import 'output_parser.dart';
import 'session_store.dart';

/// Executes an executable benchmark variant process and writes trial artifacts.
class ProcessTrialRunner {
  final LocalSessionStore store;
  final MacHostProbe probe;
  final BenchmarkOutputParser parser;
  final Logger _log;

  ProcessTrialRunner({
    required this.store,
    MacHostProbe? probe,
    BenchmarkOutputParser? parser,
    Logger? logger,
  })  : probe = probe ?? MacHostProbe(),
        parser = parser ?? BenchmarkOutputParser(logger: logger),
        _log = logger ?? Logger('ProcessTrialRunner');

  /// Resolves the executable path against [sessionDirPath] if relative.
  static String resolveExecutable(String executable, String sessionDirPath) {
    if (executable.contains('/') || executable.contains(r'\')) {
      final candidate = p.normalize(
        p.isAbsolute(executable)
            ? executable
            : p.join(sessionDirPath, executable),
      );
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return executable;
  }

  /// Runs a single trial for [variant], writes logs and metrics, and returns [TrialMetadata].
  Future<TrialMetadata> runTrial({
    required String sessionId,
    required String trialId,
    required ExecutableVariantSpec variant,
    required int round,
    required Duration timeout,
    required String sessionDirPath,
  }) async {
    final trialDir = store.trialDir(trialId);
    if (!await trialDir.exists()) {
      await trialDir.create(recursive: true);
    }

    final executable = resolveExecutable(variant.executable, sessionDirPath);

    // 1. Host probe before trial
    final deviceBefore = await probe.probe();
    final startedAt = DateTime.now().toUtc();

    int exitCode = -1;
    String stdoutStr = '';
    String stderrStr = '';
    bool timedOut = false;
    String? executionError;

    // 2. Spawn and monitor subprocess
    try {
      final process = await Process.start(
        executable,
        variant.args,
        workingDirectory: sessionDirPath,
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final stdoutDone = process.stdout
          .transform(utf8.decoder)
          .listen(stdoutBuffer.write)
          .asFuture<void>();
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .listen(stderrBuffer.write)
          .asFuture<void>();

      final exitCodeOrTimeout = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          timedOut = true;
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );

      await Future.wait([stdoutDone, stderrDone]).timeout(
        const Duration(seconds: 2),
        onTimeout: () => const [],
      );

      exitCode = exitCodeOrTimeout;
      stdoutStr = stdoutBuffer.toString();
      stderrStr = stderrBuffer.toString();
    } catch (e) {
      exitCode = -1;
      executionError = e.toString();
      stderrStr = 'Execution failure: $e\n$stderrStr';
      _log.severe('Failed to launch "$executable": $e');
    }

    final finishedAt = DateTime.now().toUtc();

    // 3. Host probe after trial
    final deviceAfter = await probe.probe();

    // 4. Write stdout and stderr logs
    await store.writeAtomic(store.trialStdoutFile(trialId), stdoutStr);
    await store.writeAtomic(store.trialStderrFile(trialId), stderrStr);

    final warnings = <String>[];

    if (timedOut) {
      final warnMsg =
          'Trial $trialId for variant "${variant.name}" timed out after ${timeout.inSeconds}s.';
      _log.severe(warnMsg);
      warnings.add(warnMsg);
    } else if (exitCode != 0) {
      final warnMsg =
          'Trial $trialId for variant "${variant.name}" exited with non-zero code $exitCode.';
      _log.severe(warnMsg);
      warnings.add(warnMsg);
    }

    // 5. Parse stdout metrics
    final parseResult = parser.parse(stdoutStr);
    warnings.addAll(parseResult.warnings);

    final hasValidDuration =
        exitCode == 0 && !timedOut && parseResult.hasDuration;

    // 6. Write results if valid, or omit if failed
    if (hasValidDuration) {
      final iterationsDir = store.trialResultsDir(trialId);
      if (!await iterationsDir.exists()) {
        await iterationsDir.create(recursive: true);
      }

      final timestampUs = DateTime.now().microsecondsSinceEpoch;
      final iterationLine = jsonEncode(<String, dynamic>{
        'iteration': 1,
        'durationUs': parseResult.durationUs,
        'timestampUs': timestampUs,
      });

      final iterationsContent = '$iterationLine\n';
      await store.writeAtomic(
        store.trialIterationsFile(trialId),
        iterationsContent,
      );

      final iterationsBytes = utf8.encode(iterationsContent);
      final hash = sha256.convert(iterationsBytes).toString();
      final indexEntries = [
        <String, dynamic>{
          'filename': 'iterations.jsonl',
          'bytes': iterationsBytes.length,
          'sha256': hash,
          'line_count': 1,
        }
      ];
      await store.writeResultsIndex(trialId, indexEntries);
    }

    // 7. Write trial metadata
    final trialMetadata = TrialMetadata(
      sessionId: sessionId,
      trialId: trialId,
      variantName: variant.name,
      round: round,
      startedAt: startedAt,
      finishedAt: finishedAt,
      exitCode: exitCode,
      durationUs: hasValidDuration ? parseResult.durationUs : null,
      deviceBefore: deviceBefore,
      deviceAfter: deviceAfter,
      warnings: warnings,
      error: timedOut
          ? 'Process timed out'
          : (exitCode != 0
              ? 'Exit code $exitCode'
              : (executionError ??
                  (!parseResult.hasDuration ? 'No runtime in stdout' : null))),
    );

    await store.writeTrialMetadata(trialMetadata);
    return trialMetadata;
  }
}
