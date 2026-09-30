import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:benchmarkhor/src/local_runner/host_probe.dart';
import 'package:benchmarkhor/src/local_runner/models.dart';
import 'package:benchmarkhor/src/local_runner/runner.dart';
import 'package:benchmarkhor/src/local_runner/session_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('LocalSessionRunner Integration', () {
    late Directory tempDir;
    late LocalSessionStore store;
    late File goodScript;
    late File failingScript;
    late File hangingScript;
    late File noMetricScript;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('runner_test_');
      store = LocalSessionStore(tempDir.path);

      goodScript = File(p.join(tempDir.path, 'good.dart'));
      await goodScript.writeAsString('''
void main() {
  print("Template(RunTime): 42.5 us.");
}
''');

      failingScript = File(p.join(tempDir.path, 'failing.dart'));
      await failingScript.writeAsString('''
import 'dart:io';
void main() {
  print("Error occurred!");
  exit(2);
}
''');

      hangingScript = File(p.join(tempDir.path, 'hanging.dart'));
      await hangingScript.writeAsString('''
import 'dart:io';
void main() {
  sleep(const Duration(seconds: 10));
}
''');

      noMetricScript = File(p.join(tempDir.path, 'no_metric.dart'));
      await noMetricScript.writeAsString('''
void main() {
  print("Hello without any timing line");
}
''');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('runs multi-round session with randomized order and produces valid artifacts', () async {
      final spec = LocalSessionSpec(
        name: 'test-session',
        rounds: 2,
        variants: {
          'v1': const ExecutableVariantSpec(
            name: 'v1',
            executable: 'dart',
            args: ['run', 'good.dart'],
          ),
          'v2': const ExecutableVariantSpec(
            name: 'v2',
            executable: 'dart',
            args: ['run', 'good.dart'],
          ),
        },
      );
      await store.writeAtomic(
        store.sessionSpecFile,
        jsonEncode(spec.toJson()),
      );

      final runner = LocalSessionRunner(
        store: store,
        probe: MacHostProbe(
          commandExecutor: (executable, args) async =>
              ProcessResult(1, 0, 'mock_out', ''),
        ),
        random: Random(42),
      );

      final finalStatus = await runner.run();
      expect(finalStatus.state, equals(LocalSessionState.completed));
      expect(finalStatus.roundsCompleted, equals(2));

      // Verify trial directories: 2 rounds * 2 variants = 4 trials
      final trialIds = await store.listExistingTrialIds();
      expect(trialIds, equals(['trial-001', 'trial-002', 'trial-003', 'trial-004']));

      for (final trialId in trialIds) {
        // trial.json
        final trialMetaFile = store.trialMetadataFile(trialId);
        expect(await trialMetaFile.exists(), isTrue);
        final meta = TrialMetadata.fromJson(
          jsonDecode(await trialMetaFile.readAsString()) as Map<String, dynamic>,
        );
        expect(meta.exitCode, equals(0));
        expect(meta.durationUs, equals(42.5));

        // stdout.log & stderr.log
        expect(await store.trialStdoutFile(trialId).exists(), isTrue);
        expect(await store.trialStderrFile(trialId).exists(), isTrue);

        // iterations.jsonl
        final iterFile = store.trialIterationsFile(trialId);
        expect(await iterFile.exists(), isTrue);
        final iterJson = jsonDecode(await iterFile.readAsString());
        expect(iterJson['durationUs'], equals(42.5));
        expect(iterJson['iteration'], equals(1));

        // results_index.json
        final indexFile = store.trialResultsIndexFile(trialId);
        expect(await indexFile.exists(), isTrue);
      }

      // session.log exists
      final logContent = await store.sessionLogFile.readAsString();
      expect(logContent, contains('Starting round 1 of 2'));
      expect(logContent, contains('Starting round 2 of 2'));
      expect(logContent, contains('Session completed successfully'));
    });

    test('logs and continues on trial failures (non-zero exit and missing runtime)', () async {
      final spec = LocalSessionSpec(
        name: 'failure-session',
        rounds: 1,
        variants: {
          'good': const ExecutableVariantSpec(
            name: 'good',
            executable: 'dart',
            args: ['run', 'good.dart'],
          ),
          'failing': const ExecutableVariantSpec(
            name: 'failing',
            executable: 'dart',
            args: ['run', 'failing.dart'],
          ),
          'no_metric': const ExecutableVariantSpec(
            name: 'no_metric',
            executable: 'dart',
            args: ['run', 'no_metric.dart'],
          ),
        },
      );
      await store.writeAtomic(
        store.sessionSpecFile,
        jsonEncode(spec.toJson()),
      );

      final runner = LocalSessionRunner(
        store: store,
        probe: MacHostProbe(
          commandExecutor: (executable, args) async =>
              ProcessResult(1, 0, 'mock_out', ''),
        ),
      );

      final status = await runner.run();
      expect(status.state, equals(LocalSessionState.completed));
      expect(status.roundsCompleted, equals(1));

      final trialIds = await store.listExistingTrialIds();
      expect(trialIds.length, equals(3));

      for (final trialId in trialIds) {
        final meta = TrialMetadata.fromJson(
          jsonDecode(await store.trialMetadataFile(trialId).readAsString())
              as Map<String, dynamic>,
        );

        if (meta.variantName == 'good') {
          expect(meta.exitCode, equals(0));
          expect(meta.durationUs, equals(42.5));
          expect(await store.trialIterationsFile(trialId).exists(), isTrue);
        } else if (meta.variantName == 'failing') {
          expect(meta.exitCode, equals(2));
          expect(meta.durationUs, isNull);
          expect(meta.warnings, isNotEmpty);
          // iterations.jsonl MUST be omitted on failure
          expect(await store.trialIterationsFile(trialId).exists(), isFalse);
        } else if (meta.variantName == 'no_metric') {
          expect(meta.exitCode, equals(0));
          expect(meta.durationUs, isNull);
          expect(meta.warnings, isNotEmpty);
          // iterations.jsonl MUST be omitted on missing runtime line
          expect(await store.trialIterationsFile(trialId).exists(), isFalse);
        }
      }
    });

    test('handles trial timeout gracefully without terminating session', () async {
      final spec = LocalSessionSpec(
        name: 'timeout-session',
        rounds: 1,
        trialTimeoutSeconds: 1,
        variants: {
          'hanging': const ExecutableVariantSpec(
            name: 'hanging',
            executable: 'dart',
            args: ['run', 'hanging.dart'],
          ),
          'good': const ExecutableVariantSpec(
            name: 'good',
            executable: 'dart',
            args: ['run', 'good.dart'],
          ),
        },
      );
      await store.writeAtomic(
        store.sessionSpecFile,
        jsonEncode(spec.toJson()),
      );

      final runner = LocalSessionRunner(
        store: store,
        timeoutOverride: const Duration(seconds: 1),
        probe: MacHostProbe(
          commandExecutor: (executable, args) async =>
              ProcessResult(1, 0, 'mock_out', ''),
        ),
      );

      final status = await runner.run();
      expect(status.state, equals(LocalSessionState.completed));
      expect(status.roundsCompleted, equals(1));

      final trialIds = await store.listExistingTrialIds();
      expect(trialIds.length, equals(2));

      for (final trialId in trialIds) {
        final meta = TrialMetadata.fromJson(
          jsonDecode(await store.trialMetadataFile(trialId).readAsString())
              as Map<String, dynamic>,
        );
        if (meta.variantName == 'hanging') {
          expect(meta.warnings.any((w) => w.contains('timed out')), isTrue);
          expect(await store.trialIterationsFile(trialId).exists(), isFalse);
        } else {
          expect(meta.durationUs, equals(42.5));
          expect(await store.trialIterationsFile(trialId).exists(), isTrue);
        }
      }
    });

    test('resumes interrupted session from roundsCompleted + 1', () async {
      final spec = LocalSessionSpec(
        name: 'resume-session',
        rounds: 3,
        variants: {
          'v1': const ExecutableVariantSpec(
            name: 'v1',
            executable: 'dart',
            args: ['run', 'good.dart'],
          ),
        },
      );
      await store.writeAtomic(
        store.sessionSpecFile,
        jsonEncode(spec.toJson()),
      );

      // Simulate partial completion: 1 of 3 rounds completed
      final initialStatus = LocalSessionStatus.initial(
        sessionId: 'resume-session',
        roundsPlanned: 3,
      ).transitionTo(
        LocalSessionState.running,
        roundsCompleted: 1,
        reason: 'Simulated crash after round 1',
      );
      await store.writeStatus(initialStatus);

      // Create dummy trial-001 to simulate round 1
      await store.trialDir('trial-001').create(recursive: true);
      await store.writeTrialMetadata(
        TrialMetadata(
          sessionId: 'resume-session',
          trialId: 'trial-001',
          variantName: 'v1',
          round: 1,
          startedAt: DateTime.now().toUtc(),
          finishedAt: DateTime.now().toUtc(),
          exitCode: 0,
          durationUs: 42.5,
        ),
      );

      final runner = LocalSessionRunner(
        store: store,
        probe: MacHostProbe(
          commandExecutor: (executable, args) async =>
              ProcessResult(1, 0, 'mock_out', ''),
        ),
      );

      // Resumes at round 2
      final status = await runner.run();
      expect(status.state, equals(LocalSessionState.completed));
      expect(status.roundsCompleted, equals(3));

      // Trials should be trial-001 (from earlier), trial-002 (round 2), trial-003 (round 3)
      final trialIds = await store.listExistingTrialIds();
      expect(trialIds, equals(['trial-001', 'trial-002', 'trial-003']));
    });

    test('clean flag resets trials and runs from round 1', () async {
      final spec = LocalSessionSpec(
        name: 'clean-session',
        rounds: 1,
        variants: {
          'v1': const ExecutableVariantSpec(
            name: 'v1',
            executable: 'dart',
            args: ['run', 'good.dart'],
          ),
        },
      );
      await store.writeAtomic(
        store.sessionSpecFile,
        jsonEncode(spec.toJson()),
      );

      // Create prior trials
      await store.trialDir('trial-999').create(recursive: true);

      final runner = LocalSessionRunner(
        store: store,
        probe: MacHostProbe(
          commandExecutor: (executable, args) async =>
              ProcessResult(1, 0, 'mock_out', ''),
        ),
      );

      final status = await runner.run(clean: true);
      expect(status.state, equals(LocalSessionState.completed));
      expect(status.roundsCompleted, equals(1));

      final trialIds = await store.listExistingTrialIds();
      expect(trialIds, equals(['trial-001']));
      expect(trialIds.contains('trial-999'), isFalse);
    });
  });
}
