/// Extract build and raster frame times from a benchmark session.
///
/// Usage:
///   dart bin/extract_dat.dart <session_path> [--output <dir>]
///
/// This script creates .dat files for each trial and aggregated metrics
/// (mean, min, max, p95, p99) for each variant.
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

  final trialEntities = trialsDir.listSync().whereType<Directory>().toList();
  // Sort trial entities to process them in order if possible (trial-001, trial-002, ...)
  trialEntities.sort((a, b) => a.path.compareTo(b.path));

  for (final entity in trialEntities) {
    final trialJsonFile = File(p.join(entity.path, 'trial.json'));
    if (!trialJsonFile.existsSync()) continue;

    final trialJson = jsonDecode(trialJsonFile.readAsStringSync());
    final variantName = trialJson['variant_name'] as String;
    final trialId = trialJson['trial_id'] as String;

    final framesFile =
        File(p.join(entity.path, 'results', 'files', 'frames.jsonl'));
    if (!framesFile.existsSync()) {
      stderr.writeln('Warning: frames.jsonl not found for $trialId');
      continue;
    }

    final buildTimes = <num>[];
    final rasterTimes = <num>[];

    for (final line in framesFile.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final frame = jsonDecode(line);
        final buildUs = frame['buildUs'] as num?;
        final rasterUs = frame['rasterUs'] as num?;
        if (buildUs != null) buildTimes.add(buildUs);
        if (rasterUs != null) rasterTimes.add(rasterUs);
      } catch (e) {
        stderr.writeln('Error parsing line in ${framesFile.path}: $e');
      }
    }

    if (buildTimes.isEmpty && rasterTimes.isEmpty) {
      stderr.writeln('Warning: No data found in ${framesFile.path}');
      continue;
    }

    final trialData = TrialData(trialId, buildTimes, rasterTimes);
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
  }

  print('Done! Files created in ${outputDir.path}');
}

void _writeDat(String path, List<num> values) {
  final file = File(path);
  file.writeAsStringSync('${values.join('\n')}\n');
}

void _writeAggregates(String outputDirPath, String metric, String variantName,
    List<List<num>> trialsData) {
  final means = <double>[];
  final mins = <double>[];
  final maxs = <double>[];
  final p95s = <double>[];
  final p99s = <double>[];

  for (final data in trialsData) {
    if (data.isEmpty) continue;
    final sorted = List<num>.from(data)..sort();
    final doubleList = data.map((e) => e.toDouble()).toList();
    final stats = Statistic.from(doubleList);

    means.add(stats.mean.toDouble());
    mins.add(stats.min.toDouble());
    maxs.add(stats.max.toDouble());
    p95s.add(percentile(sorted, 0.95));
    p99s.add(percentile(sorted, 0.99));
  }

  _writeDat(p.join(outputDirPath, '${metric}_mean_$variantName.dat'), means);
  _writeDat(p.join(outputDirPath, '${metric}_min_$variantName.dat'), mins);
  _writeDat(p.join(outputDirPath, '${metric}_max_$variantName.dat'), maxs);
  _writeDat(p.join(outputDirPath, '${metric}_p95_$variantName.dat'), p95s);
  _writeDat(p.join(outputDirPath, '${metric}_p99_$variantName.dat'), p99s);
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

class TrialData {
  final String id;
  final List<num> buildTimes;
  final List<num> rasterTimes;
  TrialData(this.id, this.buildTimes, this.rasterTimes);
}
