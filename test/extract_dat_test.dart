import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('extract_dat CLI', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('extract_dat_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('missing session.json exits 1 with clear error message', () async {
      final sessionDir = Directory(p.join(tempDir.path, 'session'));
      final trialsDir = Directory(p.join(sessionDir.path, 'trials'));
      await trialsDir.create(recursive: true);

      final result = await Process.run(
        'dart',
        ['run', 'bin/extract_dat.dart', sessionDir.path],
      );

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('session.json not found'));
    });

    test(
        'extracts change .dat files comparing non-baseline to baseline variant',
        () async {
      final sessionDir = Directory(p.join(tempDir.path, 'session'));
      final trialsDir = Directory(p.join(sessionDir.path, 'trials'));
      await trialsDir.create(recursive: true);

      // Write session.json with baseline_2026 as first variant
      final sessionJson = File(p.join(sessionDir.path, 'session.json'));
      await sessionJson.writeAsString(jsonEncode({
        'schema_version': 1,
        'name': 'test-session',
        'variants': {
          'baseline_2026': {'apk': 'base.apk'},
          'refactor': {'apk': 'refactor.apk'},
        },
        'rounds': 2,
      }));

      // Create Round 1: trial-001 (baseline_2026), trial-002 (refactor)
      // Round 1: baseline_2026 mean build = 42.0, refactor mean build = 40.0 -> change = -2.0
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-001',
        variantName: 'baseline_2026',
        round: 1,
        buildTimes: [42.0, 42.0],
        rasterTimes: [10.0, 10.0],
      );
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-002',
        variantName: 'refactor',
        round: 1,
        buildTimes: [40.0, 40.0],
        rasterTimes: [8.0, 8.0],
      );

      // Create Round 2: trial-003 (refactor), trial-004 (baseline_2026)
      // Round 2: baseline_2026 mean build = 50.0, refactor mean build = 45.0 -> change = -5.0
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-003',
        variantName: 'refactor',
        round: 2,
        buildTimes: [45.0, 45.0],
        rasterTimes: [9.0, 9.0],
      );
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-004',
        variantName: 'baseline_2026',
        round: 2,
        buildTimes: [50.0, 50.0],
        rasterTimes: [12.0, 12.0],
      );

      final outDir = Directory(p.join(tempDir.path, 'out'));

      final result = await Process.run(
        'dart',
        ['run', 'bin/extract_dat.dart', sessionDir.path, '-o', outDir.path],
      );

      expect(result.exitCode, equals(0));

      // Absolute mean files
      final baseMeanFile =
          File(p.join(outDir.path, 'build_mean_baseline_2026.dat'));
      final refactorMeanFile =
          File(p.join(outDir.path, 'build_mean_refactor.dat'));
      expect(baseMeanFile.existsSync(), isTrue);
      expect(refactorMeanFile.existsSync(), isTrue);

      // Change mean file
      final changeMeanFile =
          File(p.join(outDir.path, 'build_mean_change_refactor.dat'));
      expect(changeMeanFile.existsSync(), isTrue);

      final changeValues = (await changeMeanFile.readAsLines())
          .where((l) => l.trim().isNotEmpty)
          .map(double.parse)
          .toList();

      expect(changeValues, equals([-2.0, -5.0]));
    });

    test('mismatched trial round number fails loudly', () async {
      final sessionDir = Directory(p.join(tempDir.path, 'session'));
      final trialsDir = Directory(p.join(sessionDir.path, 'trials'));
      await trialsDir.create(recursive: true);

      final sessionJson = File(p.join(sessionDir.path, 'session.json'));
      await sessionJson.writeAsString(jsonEncode({
        'schema_version': 1,
        'variants': {
          'v1': {'apk': 'v1.apk'},
          'v2': {'apk': 'v2.apk'},
        },
      }));

      // trial-001 calculated round = 1, recorded round = 99
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-001',
        variantName: 'v1',
        round: 99,
        buildTimes: [10.0],
        rasterTimes: [5.0],
      );

      final result = await Process.run(
        'dart',
        ['run', 'bin/extract_dat.dart', sessionDir.path],
      );

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('does not match calculated round'));
    });

    test('warns and skips incomplete round in change computation', () async {
      final sessionDir = Directory(p.join(tempDir.path, 'session'));
      final trialsDir = Directory(p.join(sessionDir.path, 'trials'));
      await trialsDir.create(recursive: true);

      final sessionJson = File(p.join(sessionDir.path, 'session.json'));
      await sessionJson.writeAsString(jsonEncode({
        'schema_version': 1,
        'variants': {
          'base': {'apk': 'base.apk'},
          'alt': {'apk': 'alt.apk'},
        },
      }));

      // Round 1: trial-001 (base), trial-002 (alt) -> complete
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-001',
        variantName: 'base',
        round: 1,
        buildTimes: [10.0],
        rasterTimes: [5.0],
      );
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-002',
        variantName: 'alt',
        round: 1,
        buildTimes: [8.0],
        rasterTimes: [4.0],
      );

      // Round 2: trial-003 (base) -> alt missing
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-003',
        variantName: 'base',
        round: 2,
        buildTimes: [12.0],
        rasterTimes: [6.0],
      );

      final outDir = Directory(p.join(tempDir.path, 'out'));

      final result = await Process.run(
        'dart',
        ['run', 'bin/extract_dat.dart', sessionDir.path, '-o', outDir.path],
      );

      expect(result.exitCode, equals(0));
      expect(result.stderr,
          contains('Warning: Round 2 missing trial for variant alt'));

      final changeMeanFile =
          File(p.join(outDir.path, 'build_mean_change_alt.dat'));
      expect(changeMeanFile.existsSync(), isTrue);

      final changeValues = (await changeMeanFile.readAsLines())
          .where((l) => l.trim().isNotEmpty)
          .map(double.parse)
          .toList();

      // Only Round 1 change is present: 8.0 - 10.0 = -2.0
      expect(changeValues, equals([-2.0]));
    });

    test('logs bootstrap suggested minimum sample size', () async {
      final sessionDir = Directory(p.join(tempDir.path, 'session'));
      final trialsDir = Directory(p.join(sessionDir.path, 'trials'));
      await trialsDir.create(recursive: true);

      final sessionJson = File(p.join(sessionDir.path, 'session.json'));
      await sessionJson.writeAsString(jsonEncode({
        'schema_version': 1,
        'variants': {
          'base': {'apk': 'base.apk'},
          'alt': {'apk': 'alt.apk'},
        },
      }));

      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-001',
        variantName: 'base',
        round: 1,
        buildTimes: [46.2, 51.8],
        rasterTimes: [20.0, 22.0],
      );
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-002',
        variantName: 'alt',
        round: 1,
        buildTimes: [44.1, 48.9],
        rasterTimes: [19.0, 21.0],
      );
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-003',
        variantName: 'alt',
        round: 2,
        buildTimes: [43.7, 46.0],
        rasterTimes: [18.0, 20.0],
      );
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-004',
        variantName: 'base',
        round: 2,
        buildTimes: [44.0, 49.5],
        rasterTimes: [19.0, 21.0],
      );

      final outDir = Directory(p.join(tempDir.path, 'out'));

      final result = await Process.run(
        'dart',
        [
          'run',
          'bin/extract_dat.dart',
          sessionDir.path,
          '-o',
          outDir.path,
          '--bootstrap-sesoi',
          '0.07',
          '--bootstrap-alpha',
          '0.05',
          '--bootstrap-power',
          '0.80'
        ],
      );

      expect(result.exitCode, equals(0),
          reason: 'stdout:\n${result.stdout}\n\nstderr:\n${result.stderr}');
      expect(
        result.stdout,
        contains(
            'Bootstrap suggested minimum sample size for build_mean_change_alt:'),
      );
    });
  });
}

Future<void> _createTrial({
  required Directory trialsDir,
  required String trialId,
  required String variantName,
  int? round,
  required List<double> buildTimes,
  required List<double> rasterTimes,
}) async {
  final tDir = Directory(p.join(trialsDir.path, trialId));
  final resultsDir = Directory(p.join(tDir.path, 'results', 'files'));
  await resultsDir.create(recursive: true);

  final trialJson = File(p.join(tDir.path, 'trial.json'));
  await trialJson.writeAsString(jsonEncode({
    'trial_id': trialId,
    'variant_name': variantName,
    if (round != null) 'round': round,
  }));

  final framesFile = File(p.join(resultsDir.path, 'frames.jsonl'));
  final sink = framesFile.openWrite();
  for (var i = 0; i < buildTimes.length; i++) {
    sink.writeln(jsonEncode({
      'buildUs': buildTimes[i],
      'rasterUs': rasterTimes[i],
    }));
  }
  await sink.close();
}
