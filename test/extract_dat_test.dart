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

      final result = await Process.run('dart', [
        'run',
        'bin/extract_dat.dart',
        sessionDir.path,
      ]);

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
        await sessionJson.writeAsString(
          jsonEncode({
            'schema_version': 1,
            'name': 'test-session',
            'variants': {
              'baseline_2026': {'apk': 'base.apk'},
              'refactor': {'apk': 'refactor.apk'},
            },
            'rounds': 2,
          }),
        );

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

        final result = await Process.run('dart', [
          'run',
          'bin/extract_dat.dart',
          sessionDir.path,
          '-o',
          outDir.path,
        ]);

        expect(result.exitCode, equals(0));

        // Absolute mean files
        final baseMeanFile = File(
          p.join(outDir.path, 'build_mean_baseline_2026.dat'),
        );
        final refactorMeanFile = File(
          p.join(outDir.path, 'build_mean_refactor.dat'),
        );
        expect(baseMeanFile.existsSync(), isTrue);
        expect(refactorMeanFile.existsSync(), isTrue);

        // Change mean file
        final changeMeanFile = File(
          p.join(outDir.path, 'build_mean_change_refactor.dat'),
        );
        expect(changeMeanFile.existsSync(), isTrue);

        final changeValues = (await changeMeanFile.readAsLines())
            .where((l) => l.trim().isNotEmpty)
            .map(double.parse)
            .toList();

        expect(changeValues, equals([-2.0, -5.0]));
      },
    );

    test('mismatched trial round number fails loudly', () async {
      final sessionDir = Directory(p.join(tempDir.path, 'session'));
      final trialsDir = Directory(p.join(sessionDir.path, 'trials'));
      await trialsDir.create(recursive: true);

      final sessionJson = File(p.join(sessionDir.path, 'session.json'));
      await sessionJson.writeAsString(
        jsonEncode({
          'schema_version': 1,
          'variants': {
            'v1': {'apk': 'v1.apk'},
            'v2': {'apk': 'v2.apk'},
          },
        }),
      );

      // trial-001 calculated round = 1, recorded round = 99
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-001',
        variantName: 'v1',
        round: 99,
        buildTimes: [10.0],
        rasterTimes: [5.0],
      );

      final result = await Process.run('dart', [
        'run',
        'bin/extract_dat.dart',
        sessionDir.path,
      ]);

      expect(result.exitCode, equals(1));
      expect(result.stderr, contains('does not match calculated round'));
    });

    test('warns and skips incomplete round in change computation', () async {
      final sessionDir = Directory(p.join(tempDir.path, 'session'));
      final trialsDir = Directory(p.join(sessionDir.path, 'trials'));
      await trialsDir.create(recursive: true);

      final sessionJson = File(p.join(sessionDir.path, 'session.json'));
      await sessionJson.writeAsString(
        jsonEncode({
          'schema_version': 1,
          'variants': {
            'base': {'apk': 'base.apk'},
            'alt': {'apk': 'alt.apk'},
          },
        }),
      );

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

      final result = await Process.run('dart', [
        'run',
        'bin/extract_dat.dart',
        sessionDir.path,
        '-o',
        outDir.path,
      ]);

      expect(result.exitCode, equals(0));
      expect(
        result.stderr,
        contains('Warning: Round 2 missing trial for variant alt'),
      );

      final changeMeanFile = File(
        p.join(outDir.path, 'build_mean_change_alt.dat'),
      );
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
      await sessionJson.writeAsString(
        jsonEncode({
          'schema_version': 1,
          'variants': {
            'base': {'apk': 'base.apk'},
            'alt': {'apk': 'alt.apk'},
          },
        }),
      );

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

      final result = await Process.run('dart', [
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
        '0.80',
      ]);

      expect(
        result.exitCode,
        equals(0),
        reason: 'stdout:\n${result.stdout}\n\nstderr:\n${result.stderr}',
      );
      expect(
        result.stdout,
        contains(
          'Bootstrap suggested minimum sample size for build_mean_change_alt:',
        ),
      );
      expect(
        result.stdout,
        matches(
          RegExp(r'\[(\*| ) win:\s*(\d+|--)%\]\s+.*\bbuild_mean_change_alt\b'),
        ),
      );
    });

    test('logs asterisk marker and win rate for significant changes', () async {
      final sessionDir = Directory(p.join(tempDir.path, 'session_sig'));
      final trialsDir = Directory(p.join(sessionDir.path, 'trials'));
      await trialsDir.create(recursive: true);

      final sessionJson = File(p.join(sessionDir.path, 'session.json'));
      await sessionJson.writeAsString(
        jsonEncode({
          'schema_version': 1,
          'variants': {
            'base': {'apk': 'base.apk'},
            'alt': {'apk': 'alt.apk'},
          },
        }),
      );

      // Distinct, non-zero difference across rounds
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-001',
        variantName: 'base',
        round: 1,
        buildTimes: [100.0, 102.0],
        rasterTimes: [20.0, 20.0],
      );
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-002',
        variantName: 'alt',
        round: 1,
        buildTimes: [10.0, 12.0],
        rasterTimes: [20.0, 20.0],
      );
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-003',
        variantName: 'base',
        round: 2,
        buildTimes: [101.0, 103.0],
        rasterTimes: [20.0, 20.0],
      );
      await _createTrial(
        trialsDir: trialsDir,
        trialId: 'trial-004',
        variantName: 'alt',
        round: 2,
        buildTimes: [11.0, 13.0],
        rasterTimes: [20.0, 20.0],
      );

      final outDir = Directory(p.join(tempDir.path, 'out_sig'));

      final result = await Process.run('dart', [
        'run',
        'bin/extract_dat.dart',
        sessionDir.path,
        '-o',
        outDir.path,
      ]);

      expect(result.exitCode, equals(0));
      expect(
        result.stdout,
        matches(RegExp(r'\[\* win:100%\]\s+.*\bbuild_mean_change_alt\b')),
      );
    });

    test(
      'extracts build_n and raster_n files per variant and per phase, and computes n_change',
      () async {
        final sessionDir = Directory(p.join(tempDir.path, 'session_n'));
        final trialsDir = Directory(p.join(sessionDir.path, 'trials'));
        await trialsDir.create(recursive: true);

        final sessionJson = File(p.join(sessionDir.path, 'session.json'));
        await sessionJson.writeAsString(
          jsonEncode({
            'schema_version': 1,
            'variants': {
              'base': {'apk': 'base.apk'},
              'alt': {'apk': 'alt.apk'},
            },
            'rounds': 2,
          }),
        );

        // Round 1:
        // base has 4 frames (2 in warmup, 2 in scroll)
        await _createTrial(
          trialsDir: trialsDir,
          trialId: 'trial-001',
          variantName: 'base',
          round: 1,
          buildTimes: [10.0, 12.0, 14.0, 16.0],
          rasterTimes: [5.0, 6.0, 7.0, 8.0],
          phases: ['warmup', 'warmup', 'scroll', 'scroll'],
        );
        // alt has 3 frames (1 in warmup, 2 in scroll) -> diff overall = -1, warmup diff = -1, scroll diff = 0
        await _createTrial(
          trialsDir: trialsDir,
          trialId: 'trial-002',
          variantName: 'alt',
          round: 1,
          buildTimes: [10.0, 11.0, 12.0],
          rasterTimes: [5.0, 6.0, 7.0],
          phases: ['warmup', 'scroll', 'scroll'],
        );

        // Round 2:
        // base has 5 frames (2 in warmup, 3 in scroll)
        await _createTrial(
          trialsDir: trialsDir,
          trialId: 'trial-003',
          variantName: 'base',
          round: 2,
          buildTimes: [10.0, 12.0, 14.0, 16.0, 18.0],
          rasterTimes: [5.0, 6.0, 7.0, 8.0, 9.0],
          phases: ['warmup', 'warmup', 'scroll', 'scroll', 'scroll'],
        );
        // alt has 2 frames (1 in warmup, 1 in scroll) -> diff overall = -3, warmup diff = -1, scroll diff = -2
        await _createTrial(
          trialsDir: trialsDir,
          trialId: 'trial-004',
          variantName: 'alt',
          round: 2,
          buildTimes: [10.0, 11.0],
          rasterTimes: [5.0, 6.0],
          phases: ['warmup', 'scroll'],
        );

        final outDir = Directory(p.join(tempDir.path, 'out_n'));

        final result = await Process.run('dart', [
          'run',
          'bin/extract_dat.dart',
          sessionDir.path,
          '-o',
          outDir.path,
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason: 'stdout:\n${result.stdout}\n\nstderr:\n${result.stderr}',
        );

        // Overall frame count files
        final buildNBase = File(p.join(outDir.path, 'build_n_base.dat'));
        final rasterNBase = File(p.join(outDir.path, 'raster_n_base.dat'));
        final buildNAlt = File(p.join(outDir.path, 'build_n_alt.dat'));
        final rasterNAlt = File(p.join(outDir.path, 'raster_n_alt.dat'));

        expect(buildNBase.existsSync(), isTrue);
        expect(rasterNBase.existsSync(), isTrue);
        expect(buildNAlt.existsSync(), isTrue);
        expect(rasterNAlt.existsSync(), isTrue);

        expect(
          (await buildNBase.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(double.parse)
              .toList(),
          equals([4.0, 5.0]),
        );
        expect(
          (await buildNAlt.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(double.parse)
              .toList(),
          equals([3.0, 2.0]),
        );

        // Paired change files
        final buildNChangeAlt = File(
          p.join(outDir.path, 'build_n_change_alt.dat'),
        );
        final rasterNChangeAlt = File(
          p.join(outDir.path, 'raster_n_change_alt.dat'),
        );
        expect(buildNChangeAlt.existsSync(), isTrue);
        expect(rasterNChangeAlt.existsSync(), isTrue);

        expect(
          (await buildNChangeAlt.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(double.parse)
              .toList(),
          equals([-1.0, -3.0]),
        );

        // Per-phase files
        final buildNWarmupBase = File(
          p.join(outDir.path, 'build_n_base_warmup.dat'),
        );
        final buildNScrollBase = File(
          p.join(outDir.path, 'build_n_base_scroll.dat'),
        );
        final buildNWarmupAlt = File(
          p.join(outDir.path, 'build_n_alt_warmup.dat'),
        );
        final buildNScrollAlt = File(
          p.join(outDir.path, 'build_n_alt_scroll.dat'),
        );

        expect(
          (await buildNWarmupBase.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(double.parse)
              .toList(),
          equals([2.0, 2.0]),
        );
        expect(
          (await buildNScrollBase.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(double.parse)
              .toList(),
          equals([2.0, 3.0]),
        );
        expect(
          (await buildNWarmupAlt.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(double.parse)
              .toList(),
          equals([1.0, 1.0]),
        );
        expect(
          (await buildNScrollAlt.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(double.parse)
              .toList(),
          equals([2.0, 1.0]),
        );

        final buildNWarmupChange = File(
          p.join(outDir.path, 'build_n_change_alt_warmup.dat'),
        );
        final buildNScrollChange = File(
          p.join(outDir.path, 'build_n_change_alt_scroll.dat'),
        );
        expect(
          (await buildNWarmupChange.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(double.parse)
              .toList(),
          equals([-1.0, -1.0]),
        );
        expect(
          (await buildNScrollChange.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(double.parse)
              .toList(),
          equals([0.0, -2.0]),
        );
      },
    );

    test(
      'extracts duration and duration_change files and handles out-of-order timestamps',
      () async {
        final sessionDir = Directory(tempDir.path);
        final trialsDir = Directory(p.join(sessionDir.path, 'trials'));
        await trialsDir.create(recursive: true);

        final sessionJson = File(p.join(sessionDir.path, 'session.json'));
        await sessionJson.writeAsString(
          jsonEncode({
            'schema_version': 1,
            'variants': {
              'base': {'apk': 'base.apk'},
              'alt': {'apk': 'alt.apk'},
            },
            'rounds': 2,
          }),
        );

        // Round 1:
        // base: vsyncStarts [1000000, 1016000], rasterFinishes [1010000, 1025000] -> span = 1025000 - 1000000 = 25000 us
        await _createTrial(
          trialsDir: trialsDir,
          trialId: 'trial-001',
          variantName: 'base',
          round: 1,
          buildTimes: [5.0, 5.0],
          rasterTimes: [5.0, 5.0],
          vsyncStarts: [1000000, 1016000],
          rasterFinishes: [1010000, 1025000],
        );
        // alt: out-of-order delivery: frame 1 delivered with vsyncStart=2016000, rasterFinish=2030000; frame 2 with vsyncStart=2000000, rasterFinish=2010000
        // min(vsyncStart) = 2000000, max(rasterFinish) = 2030000 -> span = 30000 us -> change = +5000 us
        await _createTrial(
          trialsDir: trialsDir,
          trialId: 'trial-002',
          variantName: 'alt',
          round: 1,
          buildTimes: [5.0, 5.0],
          rasterTimes: [5.0, 5.0],
          vsyncStarts: [2016000, 2000000],
          rasterFinishes: [2030000, 2010000],
        );

        // Round 2:
        // base: span = 40000 us (vsync=3000000, rasterFinish=3040000)
        await _createTrial(
          trialsDir: trialsDir,
          trialId: 'trial-003',
          variantName: 'base',
          round: 2,
          buildTimes: [5.0],
          rasterTimes: [5.0],
          vsyncStarts: [3000000],
          rasterFinishes: [3040000],
        );
        // alt: span = 38000 us (vsync=4000000, rasterFinish=4038000) -> change = -2000 us
        await _createTrial(
          trialsDir: trialsDir,
          trialId: 'trial-004',
          variantName: 'alt',
          round: 2,
          buildTimes: [5.0],
          rasterTimes: [5.0],
          vsyncStarts: [4000000],
          rasterFinishes: [4038000],
        );

        final outDir = Directory(p.join(tempDir.path, 'out_duration'));

        final result = await Process.run('dart', [
          'run',
          'bin/extract_dat.dart',
          sessionDir.path,
          '-o',
          outDir.path,
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason: 'stdout:\n${result.stdout}\n\nstderr:\n${result.stderr}',
        );

        final durationBase = File(p.join(outDir.path, 'duration_base.dat'));
        final durationAlt = File(p.join(outDir.path, 'duration_alt.dat'));
        final durationChange = File(
          p.join(outDir.path, 'duration_change_alt.dat'),
        );

        expect(durationBase.existsSync(), isTrue);
        expect(durationAlt.existsSync(), isTrue);
        expect(durationChange.existsSync(), isTrue);

        expect(
          (await durationBase.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(int.parse)
              .toList(),
          equals([25000, 40000]),
        );
        expect(
          (await durationAlt.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(int.parse)
              .toList(),
          equals([30000, 38000]),
        );
        expect(
          (await durationChange.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(double.parse)
              .toList(),
          equals([5000.0, -2000.0]),
        );

        expect(
          result.stdout,
          contains(
            'Bootstrap suggested minimum sample size for duration_change_alt:',
          ),
        );
      },
    );

    test(
      'resiliently handles trials with missing frames or missing timestamps with warnings',
      () async {
        final sessionDir = Directory(p.join(tempDir.path, 'session_resilient'));
        final trialsDir = Directory(p.join(sessionDir.path, 'trials'));
        await trialsDir.create(recursive: true);

        final sessionJson = File(p.join(sessionDir.path, 'session.json'));
        await sessionJson.writeAsString(
          jsonEncode({
            'schema_version': 1,
            'variants': {
              'base': {'apk': 'base.apk'},
              'alt': {'apk': 'alt.apk'},
            },
            'rounds': 2,
          }),
        );

        // Round 1: normal trial
        await _createTrial(
          trialsDir: trialsDir,
          trialId: 'trial-001',
          variantName: 'base',
          round: 1,
          buildTimes: [10.0],
          rasterTimes: [5.0],
          vsyncStarts: [1000],
          rasterFinishes: [2000],
        );
        // alt in Round 1: frames.jsonl is empty
        await _createTrial(
          trialsDir: trialsDir,
          trialId: 'trial-002',
          variantName: 'alt',
          round: 1,
          buildTimes: [],
          rasterTimes: [],
        );

        // Round 2:
        // base has build/raster times but NO vsyncStart / rasterFinish
        await _createTrial(
          trialsDir: trialsDir,
          trialId: 'trial-003',
          variantName: 'base',
          round: 2,
          buildTimes: [10.0],
          rasterTimes: [5.0],
        );
        // alt in Round 2: normal trial
        await _createTrial(
          trialsDir: trialsDir,
          trialId: 'trial-004',
          variantName: 'alt',
          round: 2,
          buildTimes: [12.0],
          rasterTimes: [6.0],
          vsyncStarts: [3000],
          rasterFinishes: [4500],
        );

        final outDir = Directory(p.join(tempDir.path, 'out_resilient'));

        final result = await Process.run('dart', [
          'run',
          'bin/extract_dat.dart',
          sessionDir.path,
          '-o',
          outDir.path,
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason: 'stdout:\n${result.stdout}\n\nstderr:\n${result.stderr}',
        );

        // Should log warnings to stderr
        expect(result.stderr, contains('No data found in'));
        expect(result.stderr, contains('No valid vsyncStart/rasterFinish'));

        // Duration for base has only trial-001 (1000 us); duration for alt has only trial-004 (1500 us)
        final durationBase = File(p.join(outDir.path, 'duration_base.dat'));
        final durationAlt = File(p.join(outDir.path, 'duration_alt.dat'));
        expect(durationBase.existsSync(), isTrue);
        expect(durationAlt.existsSync(), isTrue);

        expect(
          (await durationBase.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(int.parse)
              .toList(),
          equals([1000]),
        );
        expect(
          (await durationAlt.readAsLines())
              .where((l) => l.isNotEmpty)
              .map(int.parse)
              .toList(),
          equals([1500]),
        );

        // Since no complete round has both base and alt duration, duration_change_alt.dat should not exist
        final durationChange = File(
          p.join(outDir.path, 'duration_change_alt.dat'),
        );
        expect(durationChange.existsSync(), isFalse);
      },
    );
  });
}

Future<void> _createTrial({
  required Directory trialsDir,
  required String trialId,
  required String variantName,
  int? round,
  required List<double> buildTimes,
  required List<double> rasterTimes,
  List<String>? phases,
  List<int>? vsyncStarts,
  List<int>? rasterFinishes,
  bool writeFramesFile = true,
}) async {
  final tDir = Directory(p.join(trialsDir.path, trialId));
  final resultsDir = Directory(p.join(tDir.path, 'results', 'files'));
  await resultsDir.create(recursive: true);

  final trialJson = File(p.join(tDir.path, 'trial.json'));
  await trialJson.writeAsString(
    jsonEncode({
      'trial_id': trialId,
      'variant_name': variantName,
      if (round != null) 'round': round,
    }),
  );

  if (!writeFramesFile) return;

  final framesFile = File(p.join(resultsDir.path, 'frames.jsonl'));
  final sink = framesFile.openWrite();
  for (var i = 0; i < buildTimes.length; i++) {
    final frameMap = <String, dynamic>{
      'buildUs': buildTimes[i],
      'rasterUs': rasterTimes[i],
      if (phases != null && i < phases.length) 'phase': phases[i],
      if (vsyncStarts != null && i < vsyncStarts.length)
        'vsyncStart': vsyncStarts[i],
      if (rasterFinishes != null && i < rasterFinishes.length)
        'rasterFinish': rasterFinishes[i],
    };
    sink.writeln(jsonEncode(frameMap));
  }
  await sink.close();
}
