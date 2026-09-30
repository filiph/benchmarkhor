import 'dart:convert';
import 'dart:io';

import 'package:benchmarkhor/src/local_runner/models.dart';
import 'package:benchmarkhor/src/local_runner/session_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('LocalSessionSpec and Models', () {
    test('parses valid session.json successfully', () {
      final json = {
        'schema_version': 1,
        'name': 'test-session',
        'description': 'A benchmark session',
        'rounds': 10,
        'trial_timeout_seconds': 60,
        'variants': {
          'baseline': {
            'executable': './baseline.exe',
            'args': ['--flag', 'val'],
            'source': 'commit 1234',
          },
          'optimized': {
            'executable': 'dart',
            'args': ['run', 'bench.dart'],
          },
        },
      };

      final spec = LocalSessionSpec.fromJson(json);
      expect(spec.name, equals('test-session'));
      expect(spec.rounds, equals(10));
      expect(spec.trialTimeoutSeconds, equals(60));
      expect(spec.variants.length, equals(2));

      final baseline = spec.variants['baseline']!;
      expect(baseline.name, equals('baseline'));
      expect(baseline.executable, equals('./baseline.exe'));
      expect(baseline.args, equals(['--flag', 'val']));
      expect(baseline.source, equals('commit 1234'));

      final serialized = spec.toJson();
      expect(serialized['name'], equals('test-session'));
      expect(serialized['rounds'], equals(10));
      expect(serialized['variants'], isA<Map<String, dynamic>>());
    });

    test('validates required fields', () {
      expect(
        () => LocalSessionSpec.fromJson({
          'name': '',
          'rounds': 5,
          'variants': {
            'v1': {'executable': 'foo'},
          },
        }),
        throwsFormatException,
      );

      expect(
        () => LocalSessionSpec.fromJson({
          'name': 'test',
          'rounds': 0,
          'variants': {
            'v1': {'executable': 'foo'},
          },
        }),
        throwsFormatException,
      );

      expect(
        () => LocalSessionSpec.fromJson({
          'name': 'test',
          'rounds': 5,
          'variants': <String, dynamic>{},
        }),
        throwsFormatException,
      );

      expect(
        () => LocalSessionSpec.fromJson({
          'name': 'test',
          'rounds': 5,
          'variants': {
            'v1': {'executable': ''},
          },
        }),
        throwsFormatException,
      );
    });

    test('LocalSessionStatus handles transitions and history', () {
      final initial = LocalSessionStatus.initial(
        sessionId: 'test-session',
        roundsPlanned: 5,
      );
      expect(initial.state, equals(LocalSessionState.queued));
      expect(initial.roundsCompleted, equals(0));
      expect(initial.history, isEmpty);

      final running = initial.transitionTo(
        LocalSessionState.running,
        reason: 'Starting round 1',
        currentTrial: 'trial-001',
      );
      expect(running.state, equals(LocalSessionState.running));
      expect(running.currentTrial, equals('trial-001'));
      expect(running.history.length, equals(1));
      expect(running.history.first.from, equals('queued'));
      expect(running.history.first.to, equals('running'));

      final completed = running.transitionTo(
        LocalSessionState.completed,
        roundsCompleted: 5,
        reason: 'All rounds finished',
      );
      expect(completed.state, equals(LocalSessionState.completed));
      expect(completed.roundsCompleted, equals(5));
      expect(completed.history.length, equals(2));

      final json = completed.toJson();
      final restored = LocalSessionStatus.fromJson(json);
      expect(restored.sessionId, equals('test-session'));
      expect(restored.state, equals(LocalSessionState.completed));
      expect(restored.roundsCompleted, equals(5));
      expect(restored.history.length, equals(2));
    });

    test('TrialMetadata serializes and deserializes', () {
      final now = DateTime.now().toUtc();
      final metadata = TrialMetadata(
        sessionId: 'session-1',
        trialId: 'trial-001',
        variantName: 'baseline',
        round: 1,
        startedAt: now,
        finishedAt: now.add(const Duration(seconds: 1)),
        exitCode: 0,
        durationUs: 1234.5,
        deviceBefore: {'thermal_pressure': '0'},
        deviceAfter: {'thermal_pressure': '0'},
        warnings: ['sample warning'],
      );

      final json = metadata.toJson();
      final restored = TrialMetadata.fromJson(json);
      expect(restored.trialId, equals('trial-001'));
      expect(restored.durationUs, equals(1234.5));
      expect(restored.deviceBefore['thermal_pressure'], equals('0'));
      expect(restored.warnings, contains('sample warning'));
    });
  });

  group('LocalSessionStore', () {
    late Directory tempDir;
    late LocalSessionStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('local_session_store_test_');
      store = LocalSessionStore(tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('formatTrialId pads numbers correctly', () {
      expect(LocalSessionStore.formatTrialId(1), equals('trial-001'));
      expect(LocalSessionStore.formatTrialId(15), equals('trial-015'));
      expect(LocalSessionStore.formatTrialId(123), equals('trial-123'));
    });

    test('writeAtomic updates file correctly', () async {
      final file = File(p.join(tempDir.path, 'nested', 'test.txt'));
      await store.writeAtomic(file, 'atomic hello');
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), equals('atomic hello'));
      expect(await File('${file.path}.tmp').exists(), isFalse);
    });

    test('appendLog writes timestamped messages', () async {
      await store.appendLog('First message');
      await store.appendLog('Second message');
      final logContent = await store.sessionLogFile.readAsString();
      expect(logContent, contains('First message'));
      expect(logContent, contains('Second message'));
      expect(logContent, contains('[20'));
    });

    test('initOrResumeStatus creates initial status and resumes on subsequent calls', () async {
      // Write session.json
      final sessionSpec = LocalSessionSpec(
        name: 'test-session',
        rounds: 3,
        variants: {
          'v1': const ExecutableVariantSpec(name: 'v1', executable: 'echo'),
        },
      );
      await store.writeAtomic(
        store.sessionSpecFile,
        jsonEncode(sessionSpec.toJson()),
      );

      // First run: initializes
      final status1 = await store.initOrResumeStatus();
      expect(status1.sessionId, equals('test-session'));
      expect(status1.roundsPlanned, equals(3));
      expect(status1.roundsCompleted, equals(0));
      expect(status1.state, equals(LocalSessionState.queued));
      expect(await store.statusFile.exists(), isTrue);

      // Update status to round 1 completed
      final updated = status1.transitionTo(
        LocalSessionState.running,
        roundsCompleted: 1,
        reason: 'Finished round 1',
      );
      await store.writeStatus(updated);

      // Second run: resumes
      final status2 = await store.initOrResumeStatus();
      expect(status2.roundsCompleted, equals(1));
      expect(status2.state, equals(LocalSessionState.running));

      final log = await store.sessionLogFile.readAsString();
      expect(log, contains('Resuming session "test-session" from round 2 of 3'));

      // Run with clean: wipes and restarts
      final status3 = await store.initOrResumeStatus(clean: true);
      expect(status3.roundsCompleted, equals(0));
      expect(status3.state, equals(LocalSessionState.queued));
    });

    test('listExistingTrialIds finds and sorts trial dirs', () async {
      await store.trialDir('trial-002').create(recursive: true);
      await store.trialDir('trial-001').create(recursive: true);
      await store.trialDir('trial-010').create(recursive: true);

      final trialIds = await store.listExistingTrialIds();
      expect(trialIds, equals(['trial-001', 'trial-002', 'trial-010']));
    });

    test('writes results_index.json and trial.json atomically', () async {
      final now = DateTime.now().toUtc();
      final metadata = TrialMetadata(
        sessionId: 'session-1',
        trialId: 'trial-001',
        variantName: 'v1',
        round: 1,
        startedAt: now,
        finishedAt: now,
        exitCode: 0,
      );
      await store.writeTrialMetadata(metadata);
      expect(await store.trialMetadataFile('trial-001').exists(), isTrue);

      final resultsEntries = [
        {
          'filename': 'iterations.jsonl',
          'bytes': 100,
          'sha256': 'abc123',
          'line_count': 1,
        }
      ];
      await store.writeResultsIndex('trial-001', resultsEntries);
      expect(await store.trialResultsIndexFile('trial-001').exists(), isTrue);

      final readIndex = jsonDecode(
        await store.trialResultsIndexFile('trial-001').readAsString(),
      );
      expect(readIndex[0]['filename'], equals('iterations.jsonl'));
    });
  });
}
