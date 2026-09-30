import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Local Runner End-to-End', () {
    late Directory tempDir;
    late Directory sessionDir;
    late Directory outputDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('local_runner_e2e_');
      sessionDir = Directory(p.join(tempDir.path, 'session'));
      await sessionDir.create(recursive: true);
      outputDir = Directory(p.join(tempDir.path, 'extracted_dat'));

      // Create synthetic benchmark scripts in session directory
      final baselineScript = File(p.join(sessionDir.path, 'baseline.dart'));
      await baselineScript.writeAsString('''
void main() {
  print("Template(RunTime): 100.0 us.");
}
''');

      final optimizedScript = File(p.join(sessionDir.path, 'optimized.dart'));
      await optimizedScript.writeAsString('''
void main() {
  print("Template(RunTime): 85.0 us.");
}
''');

      final sessionJson = {
        'schema_version': 1,
        'name': 'e2e-mac-session',
        'rounds': 3,
        'variants': {
          'baseline': {
            'executable': 'dart',
            'args': ['run', 'baseline.dart'],
            'source': 'Baseline compile',
          },
          'optimized': {
            'executable': 'dart',
            'args': ['run', 'optimized.dart'],
            'source': 'Optimized compile',
          },
        },
      };

      await File(p.join(sessionDir.path, 'session.json')).writeAsString(
        jsonEncode(sessionJson),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('runs session via bin/local_runner.dart and extracts dat via bin/extract_dat.dart', () async {
      // 1. Execute local_runner.dart CLI
      final runnerResult = await Process.run(
        Platform.resolvedExecutable,
        ['bin/local_runner.dart', sessionDir.path, '--verbose'],
      );

      expect(
        runnerResult.exitCode,
        equals(0),
        reason: 'local_runner stdout:\n${runnerResult.stdout}\nstderr:\n${runnerResult.stderr}',
      );

      // Verify trial artifacts
      final statusFile = File(p.join(sessionDir.path, 'status.json'));
      expect(await statusFile.exists(), isTrue);
      final statusJson = jsonDecode(await statusFile.readAsString());
      expect(statusJson['state'], equals('completed'));
      expect(statusJson['rounds_completed'], equals(3));

      // 3 rounds * 2 variants = 6 trials
      final trialsDir = Directory(p.join(sessionDir.path, 'trials'));
      final trials = trialsDir.listSync().whereType<Directory>().toList();
      expect(trials.length, equals(6));

      for (final trial in trials) {
        expect(File(p.join(trial.path, 'trial.json')).existsSync(), isTrue);
        expect(File(p.join(trial.path, 'stdout.log')).existsSync(), isTrue);
        expect(File(p.join(trial.path, 'stderr.log')).existsSync(), isTrue);
        expect(
          File(p.join(trial.path, 'results', 'iterations.jsonl')).existsSync(),
          isTrue,
        );
        expect(
          File(p.join(trial.path, 'results_index.json')).existsSync(),
          isTrue,
        );
      }

      // 2. Execute extract_dat.dart CLI on the generated session
      final extractResult = await Process.run(
        Platform.resolvedExecutable,
        [
          'bin/extract_dat.dart',
          sessionDir.path,
          '--output',
          outputDir.path,
          '--verbose',
        ],
      );

      expect(
        extractResult.exitCode,
        equals(0),
        reason: 'extract_dat stdout:\n${extractResult.stdout}\nstderr:\n${extractResult.stderr}',
      );

      // Verify extracted .dat files exist and contain valid measurements
      final meanBaselineFile = File(
        p.join(outputDir.path, 'iteration_duration_mean_baseline.dat'),
      );
      final meanOptimizedFile = File(
        p.join(outputDir.path, 'iteration_duration_mean_optimized.dat'),
      );

      expect(await meanBaselineFile.exists(), isTrue);
      expect(await meanOptimizedFile.exists(), isTrue);

      final baselineLines = (await meanBaselineFile.readAsLines())
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final optimizedLines = (await meanOptimizedFile.readAsLines())
          .where((l) => l.trim().isNotEmpty)
          .toList();

      // 3 rounds = 3 trial values per variant
      expect(baselineLines.length, equals(3));
      expect(optimizedLines.length, equals(3));

      for (final line in baselineLines) {
        expect(double.parse(line), equals(100.0));
      }
      for (final line in optimizedLines) {
        expect(double.parse(line), equals(85.0));
      }

      // Change file relative to baseline should exist
      final changeFile = File(
        p.join(outputDir.path, 'iteration_duration_mean_change_optimized.dat'),
      );
      expect(await changeFile.exists(), isTrue);
    });
  });
}
