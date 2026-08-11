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
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:t_stats/t_stats.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('output',
        abbr: 'o', help: 'Output directory', defaultsTo: 'extracted_dat')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

  final argResults = parser.parse(arguments);

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

  print('Extracting data from $sessionPath to ${outputDir.path}...');

  final variantTrials = <String, List<TrialData>>{};

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

  _writeRoundTemperatures(
      outputDir.path, endTemperatures, variantTrials.length);

  print('Done! Files created in ${outputDir.path}');
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
