/// Extract build and raster frame times from a benchmark session.
///
/// Usage:
///   dart bin/extract_dat.dart <session_path> [--output <dir>]
///
/// This script creates .dat files for each trial and, for each variant, one
/// value per trial for every metric (mean, min, max, p95, p99, p95
/// superquantile), for both the build and the raster timing. When frames carry
/// a `phase` tag, the metrics are also written per phase. It also writes
/// `temperature.dat` with the device temperature at the end of each round.
/// It also writes change .dat files relative to the baseline variant (the first
/// variant listed in session.json).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:t_stats/t_stats.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('output',
        abbr: 'o', help: 'Output directory', defaultsTo: 'extracted_dat')
    ..addFlag('verbose', help: 'Verbose logging.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  final argResults = parser.parse(arguments);

  if (argResults.flag('verbose')) {
    Logger.root.level = Level.ALL;
  } else {
    Logger.root.level = Level.INFO;
  }

  Logger.root.onRecord.listen((record) {
    final strBuf = StringBuffer();
    if (record.level != Level.INFO) {
      strBuf.write(record.level.name);
      strBuf.write(': ');
    }
    strBuf.write(record.message);
    stdout.writeln(strBuf.toString());
  });
  final log = Logger('extract_dat');

  if (argResults['help'] as bool || argResults.rest.isEmpty) {
    print('Usage: dart bin/extract_dat.dart <session_path> [options]');
    print(parser.usage);
    return;
  }

  final sessionPath = argResults.rest.first;
  final outputDir = Directory(argResults['output'] as String);

  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final trialsDir = Directory(p.join(sessionPath, 'trials'));
  if (!trialsDir.existsSync()) {
    stderr.writeln('Error: trials directory not found at ${trialsDir.path}');
    exit(1);
  }

  final sessionJsonFile = File(p.join(sessionPath, 'session.json'));
  if (!sessionJsonFile.existsSync()) {
    stderr.writeln('Error: session.json not found at ${sessionJsonFile.path}');
    exit(1);
  }

  Map<String, dynamic> sessionJson;
  try {
    sessionJson =
        jsonDecode(sessionJsonFile.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    stderr.writeln(
        'Error: Failed to parse session.json at ${sessionJsonFile.path}: $e');
    exit(1);
  }

  final variantsMap = sessionJson['variants'] as Map<String, dynamic>?;
  if (variantsMap == null || variantsMap.isEmpty) {
    stderr.writeln('Error: "variants" map missing or empty in session.json');
    exit(1);
  }

  final variantNames = variantsMap.keys.toList();
  final baselineVariant = variantNames.first;
  final variantCount = variantNames.length;

  log.info('Extracting data from $sessionPath to ${outputDir.path}...');

  final variantTrials = <String, List<TrialData>>{};
  final roundTrials = <int, Map<String, TrialData>>{};

  // The temperature at the end of each Trial, in the order the Trials ran.
  final endTemperatures = <double?>[];

  final trialEntities = trialsDir.listSync().whereType<Directory>().toList();
  // Sort trial entities to process them in order if possible (trial-001, trial-002, ...)
  trialEntities.sort((a, b) => a.path.compareTo(b.path));

  for (final entity in trialEntities) {
    final trialJsonFile = File(p.join(entity.path, 'trial.json'));
    if (!trialJsonFile.existsSync()) continue;

    final trialJson =
        jsonDecode(trialJsonFile.readAsStringSync()) as Map<String, dynamic>;
    final variantName = trialJson['variant_name'] as String;
    final trialId = trialJson['trial_id'] as String;

    final trialNumber = _parseTrialNumber(trialId);
    final calculatedRound = (trialNumber - 1) ~/ variantCount + 1;

    if (trialJson.containsKey('round') && trialJson['round'] != null) {
      final recordedRound = trialJson['round'] as int;
      if (recordedRound != calculatedRound) {
        stderr.writeln(
            'Error: Trial $trialId recorded round ($recordedRound) does not match calculated round ($calculatedRound).');
        exit(1);
      }
    }

    endTemperatures.add(_endTemperature(trialJson));

    final framesFile =
        File(p.join(entity.path, 'results', 'files', 'frames.jsonl'));
    if (!framesFile.existsSync()) {
      stderr.writeln('Warning: frames.jsonl not found for $trialId');
      continue;
    }

    final buildTimes = <num>[];
    final rasterTimes = <num>[];
    final buildTimesByPhase = <String, List<num>>{};
    final rasterTimesByPhase = <String, List<num>>{};

    for (final line in framesFile.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final frame = jsonDecode(line);
        final buildUs = frame['buildUs'] as num?;
        final rasterUs = frame['rasterUs'] as num?;
        final phase = (frame['phase'] as String?)?.trim() ?? '';
        if (buildUs != null) {
          buildTimes.add(buildUs);
          if (phase.isNotEmpty) {
            buildTimesByPhase.putIfAbsent(phase, () => []).add(buildUs);
          }
        }
        if (rasterUs != null) {
          rasterTimes.add(rasterUs);
          if (phase.isNotEmpty) {
            rasterTimesByPhase.putIfAbsent(phase, () => []).add(rasterUs);
          }
        }
      } catch (e) {
        stderr.writeln('Error parsing line in ${framesFile.path}: $e');
      }
    }

    if (buildTimes.isEmpty && rasterTimes.isEmpty) {
      stderr.writeln('Warning: No data found in ${framesFile.path}');
      continue;
    }

    final trialData = TrialData(trialId, buildTimes, rasterTimes,
        buildTimesByPhase, rasterTimesByPhase);
    variantTrials.putIfAbsent(variantName, () => []).add(trialData);
    roundTrials.putIfAbsent(calculatedRound, () => {})[variantName] = trialData;

    // Write per-trial files
    _writeDat(p.join(outputDir.path, 'build_${variantName}_$trialId.dat'),
        buildTimes);
    _writeDat(p.join(outputDir.path, 'raster_${variantName}_$trialId.dat'),
        rasterTimes);
  }

  // Write aggregated files
  for (final entry in variantTrials.entries) {
    final variantName = entry.key;
    final trials = entry.value;

    _writeAggregates(outputDir.path, 'build', variantName,
        trials.map((t) => t.buildTimes).toList());
    _writeAggregates(outputDir.path, 'raster', variantName,
        trials.map((t) => t.rasterTimes).toList());

    // Phases are optional. Frames without a phase tag are only part of the
    // all-phases aggregates above.
    for (final phase in _phasesOf(trials)) {
      _writeAggregates(
          outputDir.path,
          'build',
          '${variantName}_$phase',
          trials
              .map((t) => t.buildTimesByPhase[phase] ?? const <num>[])
              .toList());
      _writeAggregates(
          outputDir.path,
          'raster',
          '${variantName}_$phase',
          trials
              .map((t) => t.rasterTimesByPhase[phase] ?? const <num>[])
              .toList());
    }
  }

  _writeRoundTemperatures(outputDir.path, endTemperatures, variantCount);

  // Validate missing trials/rounds
  final maxRound = roundTrials.keys.isEmpty ? 0 : roundTrials.keys.reduce(max);
  for (var r = 1; r <= maxRound; r++) {
    for (final v in variantNames) {
      if (roundTrials[r]?[v] == null) {
        stderr.writeln('Warning: Round $r missing trial for variant $v');
      }
    }
  }

  // Write change aggregate files for non-baseline variants
  final nonBaselineVariants = variantNames.sublist(1);
  final allTrialsList = variantTrials.values.expand((t) => t).toList();
  final phases = _phasesOf(allTrialsList);

  for (final v in nonBaselineVariants) {
    // All-phases change aggregates
    _writeChangeAggregatesForTiming(
      outputDirPath: outputDir.path,
      timing: 'build',
      baselineVariant: baselineVariant,
      variantName: v,
      maxRound: maxRound,
      roundTrials: roundTrials,
      log: log,
    );
    _writeChangeAggregatesForTiming(
      outputDirPath: outputDir.path,
      timing: 'raster',
      baselineVariant: baselineVariant,
      variantName: v,
      maxRound: maxRound,
      roundTrials: roundTrials,
      log: log,
    );

    // Per-phase change aggregates
    for (final phase in phases) {
      _writeChangeAggregatesForTiming(
        outputDirPath: outputDir.path,
        timing: 'build',
        baselineVariant: baselineVariant,
        variantName: v,
        maxRound: maxRound,
        roundTrials: roundTrials,
        phase: phase,
        log: log,
      );
      _writeChangeAggregatesForTiming(
        outputDirPath: outputDir.path,
        timing: 'raster',
        baselineVariant: baselineVariant,
        variantName: v,
        maxRound: maxRound,
        roundTrials: roundTrials,
        phase: phase,
        log: log,
      );
    }
  }

  log.info('Done! Files created in ${outputDir.path}');
}

int _parseTrialNumber(String trialId) {
  final match = RegExp(r'trial-(\d+)').firstMatch(trialId);
  if (match != null) {
    return int.parse(match.group(1)!);
  }
  return int.tryParse(trialId.replaceAll(RegExp(r'\D'), '')) ?? 0;
}

/// All phase tags seen in [trials], sorted for stable output.
List<String> _phasesOf(List<TrialData> trials) {
  final phases = <String>{};
  for (final trial in trials) {
    phases.addAll(trial.buildTimesByPhase.keys);
    phases.addAll(trial.rasterTimesByPhase.keys);
  }
  return phases.toList()..sort();
}

/// Writes one temperature per Round, taken from the last Trial of each Round.
///
/// Trials don't record which Round they belong to, so Rounds are reconstructed
/// from the fact that every Round runs every Variant exactly once: with
/// [variantCount] variants, every [variantCount]-th Trial ends a Round. An
/// incomplete trailing Round is ignored, so the number of values matches the
/// number of values in the per-Variant aggregates.
void _writeRoundTemperatures(
    String outputDirPath, List<double?> endTemperatures, int variantCount) {
  if (variantCount == 0) return;
  final temperatures = <double>[];
  for (var i = variantCount - 1;
      i < endTemperatures.length;
      i += variantCount) {
    final temperature = endTemperatures[i];
    if (temperature == null) {
      stderr.writeln('Warning: no temperature recorded for round '
          '${i ~/ variantCount + 1}');
      continue;
    }
    temperatures.add(temperature);
  }
  if (temperatures.isEmpty) return;
  _writeDat(p.join(outputDirPath, 'temperature.dat'), temperatures);
}

/// The temperature (in Celsius) of the SoC thermal zone, or, when the device
/// doesn't report one, of the hottest zone it does report.
double? _endTemperature(Map<String, dynamic> trialJson) {
  final deviceAfter = trialJson['device_after'] as Map<String, dynamic>?;
  final zones = deviceAfter?['temperatures'] as List?;
  if (zones == null) return null;
  double? hottest;
  for (final zone in zones) {
    if (zone is! Map) continue;
    final value = double.tryParse(zone['temp']?.toString() ?? '');
    if (value == null) continue;
    // Zones are reported in millidegrees.
    final celsius = value / 1000.0;
    if (zone['type'] == 'soc-thermal') return celsius;
    if (hottest == null || celsius > hottest) hottest = celsius;
  }
  return hottest;
}

void _writeDat(String path, List<num> values) {
  final file = File(path);
  file.writeAsStringSync('${values.join('\n')}\n');
}

/// Writes one value per trial for each metric, for one [timing] (`build` or
/// `raster`) of one variant.
void _writeAggregates(String outputDirPath, String timing, String variantName,
    List<List<num>> trialsData) {
  final firsts = <double>[];
  final means = <double>[];
  final mins = <double>[];
  final maxs = <double>[];
  final p95s = <double>[];
  final p99s = <double>[];
  final p95Superquantiles = <double>[];

  for (final data in trialsData) {
    if (data.isEmpty) continue;
    firsts.add(data.first.toDouble());
    final sorted = List<num>.from(data)..sort();
    p95Superquantiles.add(superquantile(sorted, 0.95));
    if (data.length == 1) {
      // A phase can consist of a single frame, which Statistic refuses.
      final only = data.single.toDouble();
      means.add(only);
      mins.add(only);
      maxs.add(only);
      p95s.add(only);
      p99s.add(only);
      continue;
    }
    final doubleList = data.map((e) => e.toDouble()).toList();
    final stats = Statistic.from(doubleList);

    means.add(stats.mean.toDouble());
    mins.add(stats.min.toDouble());
    maxs.add(stats.max.toDouble());
    p95s.add(percentile(sorted, 0.95));
    p99s.add(percentile(sorted, 0.99));
  }

  _writeDat(p.join(outputDirPath, '${timing}_first_$variantName.dat'), firsts);
  _writeDat(p.join(outputDirPath, '${timing}_mean_$variantName.dat'), means);
  _writeDat(p.join(outputDirPath, '${timing}_min_$variantName.dat'), mins);
  _writeDat(p.join(outputDirPath, '${timing}_max_$variantName.dat'), maxs);
  _writeDat(p.join(outputDirPath, '${timing}_p95_$variantName.dat'), p95s);
  _writeDat(p.join(outputDirPath, '${timing}_p99_$variantName.dat'), p99s);
  _writeDat(
      p.join(outputDirPath, '${timing}_p95superquantile_$variantName.dat'),
      p95Superquantiles);
}

Metrics? _computeMetrics(List<num> data) {
  if (data.isEmpty) return null;
  final first = data.first.toDouble();
  final sorted = List<num>.from(data)..sort();
  final p95sq = superquantile(sorted, 0.95);
  if (data.length == 1) {
    final only = data.single.toDouble();
    return Metrics(
      first: only,
      mean: only,
      min: only,
      max: only,
      p95: only,
      p99: only,
      p95superquantile: p95sq,
    );
  }
  final doubleList = data.map((e) => e.toDouble()).toList();
  final stats = Statistic.from(doubleList);
  return Metrics(
    first: first,
    mean: stats.mean.toDouble(),
    min: stats.min.toDouble(),
    max: stats.max.toDouble(),
    p95: percentile(sorted, 0.95),
    p99: percentile(sorted, 0.99),
    p95superquantile: p95sq,
  );
}

final class Metrics {
  final double first;
  final double mean;
  final double min;
  final double max;
  final double p95;
  final double p99;
  final double p95superquantile;

  const Metrics({
    required this.first,
    required this.mean,
    required this.min,
    required this.max,
    required this.p95,
    required this.p99,
    required this.p95superquantile,
  });

  double getMetric(MetricType type) {
    switch (type) {
      case MetricType.first:
        return first;
      case MetricType.mean:
        return mean;
      case MetricType.min:
        return min;
      case MetricType.max:
        return max;
      case MetricType.p95:
        return p95;
      case MetricType.p99:
        return p99;
      case MetricType.p95superquantile:
        return p95superquantile;
    }
  }
}

enum MetricType {
  first,
  mean,
  min,
  max,
  p95,
  p99,
  p95superquantile,
}

void _writeChangeAggregatesForTiming({
  required String outputDirPath,
  required String timing,
  required String baselineVariant,
  required String variantName,
  required int maxRound,
  required Map<int, Map<String, TrialData>> roundTrials,
  String? phase,
  required Logger log,
}) {
  final changeLists = {for (final m in MetricType.values) m: <double>[]};
  final baseMetricsList = <Metrics>[];
  final varMetricsList = <Metrics>[];

  for (var r = 1; r <= maxRound; r++) {
    final baseTrial = roundTrials[r]?[baselineVariant];
    final varTrial = roundTrials[r]?[variantName];
    if (baseTrial == null || varTrial == null) continue;

    List<num> baseData;
    List<num> varData;
    if (timing == 'build') {
      baseData = phase == null
          ? baseTrial.buildTimes
          : (baseTrial.buildTimesByPhase[phase] ?? const <num>[]);
      varData = phase == null
          ? varTrial.buildTimes
          : (varTrial.buildTimesByPhase[phase] ?? const <num>[]);
    } else {
      baseData = phase == null
          ? baseTrial.rasterTimes
          : (baseTrial.rasterTimesByPhase[phase] ?? const <num>[]);
      varData = phase == null
          ? varTrial.rasterTimes
          : (varTrial.rasterTimesByPhase[phase] ?? const <num>[]);
    }

    final baseMetrics = _computeMetrics(baseData);
    final varMetrics = _computeMetrics(varData);
    if (baseMetrics == null || varMetrics == null) continue;

    baseMetricsList.add(baseMetrics);
    varMetricsList.add(varMetrics);

    for (final m in MetricType.values) {
      final change = varMetrics.getMetric(m) - baseMetrics.getMetric(m);
      changeLists[m]!.add(change);
    }
  }

  final suffix = phase == null ? variantName : '${variantName}_$phase';
  for (final metric in MetricType.values) {
    final designation = '${timing}_${metric.name}_change_$suffix';
    final values = changeLists[metric]!;
    if (values.isNotEmpty) {
      _writeDat(p.join(outputDirPath, '$designation.dat'), values);
    }

    // Show statistical difference.
    final baseData = baseMetricsList.map((m) => m.getMetric(metric));
    final varData = varMetricsList.map((met) => met.getMetric(metric));
    if (baseData.length < 2 || varData.length < 2) {
      log.fine('$designation data length is less than 2, cannot create stats');
    } else {
      final baseStats = Statistic.from(baseData, name: '$designation baseline');
      final varStats = Statistic.from(varData, name: '$designation variant');
      final changeStats =
          Statistic.from(changeLists[metric]!, name: designation);

      final medianIsDifferent = varStats.isDifferentFrom(baseStats);
      final meanIsDifferent = (varStats.lowerBound < baseStats.lowerBound &&
              varStats.upperBound < baseStats.lowerBound) ||
          (varStats.lowerBound > baseStats.upperBound &&
              varStats.upperBound > baseStats.upperBound);

      final significanceMarker = (medianIsDifferent && meanIsDifferent)
          ? 'BOTH'
          : medianIsDifferent
              ? 'medi'
              : meanIsDifferent
                  ? 'mean'
                  : '    ';
      log.info('$significanceMarker ${changeStats.toString()}');
    }
  }
}

double percentile(List<num> sorted, double p) {
  if (sorted.isEmpty) return 0;
  if (sorted.length == 1) return sorted[0].toDouble();
  final index = p * (sorted.length - 1);
  final lo = index.floor();
  final hi = index.ceil();
  if (lo == hi) return sorted[lo].toDouble();
  final frac = index - lo;
  return sorted[lo] * (1 - frac) + sorted[hi] * frac;
}

/// The mean of the worst `1 - p` of [sorted], which must be sorted ascending.
///
/// The tail rarely contains a whole number of values: with 703 values, the
/// worst 5% are 35.15 of them. The 35 worst count in full and the next one
/// counts for the remaining 0.15, so the result doesn't jump when a single
/// value crosses the tail boundary. See
/// `doc/adr/0004-superquantile-tail-is-interpolated.md`.
///
/// When the tail is thinner than one value — 20 values or fewer, at p95 — this
/// is the largest value.
double superquantile(List<num> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final tailWeight = sorted.length * (1 - p);
  if (tailWeight <= 0) return sorted.last.toDouble();
  final whole = tailWeight.floor();
  var sum = 0.0;
  for (var i = sorted.length - whole; i < sorted.length; i++) {
    sum += sorted[i].toDouble();
  }
  final fraction = tailWeight - whole;
  if (fraction > 0) {
    sum += sorted[sorted.length - whole - 1].toDouble() * fraction;
  }
  return sum / tailWeight;
}

class TrialData {
  final String id;
  final List<num> buildTimes;
  final List<num> rasterTimes;

  /// Build times of only those frames tagged with a given phase.
  final Map<String, List<num>> buildTimesByPhase;

  /// Raster times of only those frames tagged with a given phase.
  final Map<String, List<num>> rasterTimesByPhase;

  TrialData(this.id, this.buildTimes, this.rasterTimes, this.buildTimesByPhase,
      this.rasterTimesByPhase);
}
