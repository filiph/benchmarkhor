import 'dart:io';

import 'package:args/args.dart';
import 'package:benchmarkhor/benchmark_result.dart';
import 'package:benchmarkhor/extract.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'src/read_benchmark_file.dart';

Future<int> main(List<String> args) async {
  final parser = ArgParser();
  parser.addFlag('sort',
      abbr: 's',
      help: 'Sort measurements before saving. '
          'This radically lowers the size of the resulting .benchmark file. '
          'On the other hand, if you expect to ever care about '
          'the order of measurements in the future, you might want to avoid this. '
          'This defaults to true when type is `flutter-profile`, otherwise '
          'it defaults to false.',
      defaultsTo: null);
  parser.addFlag('help', abbr: 'h', help: 'Show help.', defaultsTo: false);
  parser.addFlag('verbose',
      abbr: 'v', help: 'Verbose output', defaultsTo: false);
  parser.addOption('label',
      abbr: 'l',
      help: 'Set the label of the resulting merged benchmark '
          'to this string.',
      valueHelp: 'Foo');
  var argResults = parser.parse(args);

  if (argResults['verbose']) {
    Logger.root.level = Level.ALL;
  } else {
    Logger.root.level = Level.INFO;
  }

  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });

  if (argResults['help'] || argResults.rest.length < 2) {
    print('Merges two or more .benchmark files into one with '
        'merged measurements from all of them.\n'
        '\n'
        'Usage:\n'
        '\tbenchmerge one.benchmark two.benchmark [...]\n'
        '\n');
    print(parser.usage);
    return 2;
  }

  final results = <BenchmarkResult>[];

  for (final filename in argResults.rest) {
    final result = await readFromFile(filename);
    results.add(result);
  }

  var label = '${results.first.label} (merged)';
  if (argResults['label'] != null) {
    log.fine('Overriding original label ("$label") with user-provided one: '
        '"${argResults['label']}"');
    label = argResults['label'];
  }

  bool shouldSortMeasurements;
  if (argResults['sort'] == null) {
    if (results.first.type == BenchmarkResult.flutterProfileType) {
      shouldSortMeasurements = true;
    } else {
      shouldSortMeasurements = false;
    }
  } else {
    shouldSortMeasurements = argResults['sort'];
  }
  log.fine('Sorting ${shouldSortMeasurements ? 'enabled' : 'disabled'}');

  final series = <MeasurementSeries>[];

  for (final firstBenchmarkSerie in results.first.series) {
    log.fine('Merging series: ${firstBenchmarkSerie.label}');

    final data = <int>[];

    for (final result in results) {
      final serie = result.series
          // XXX: We just assume all benchmarks have the same set of series
          //      as the first one.
          .singleWhere((s) => s.label == firstBenchmarkSerie.label);
      data.addAll(serie.measurements);
    }

    if (shouldSortMeasurements) {
      data.sort();
    }

    series.add(MeasurementSeries(firstBenchmarkSerie.label, data));
  }

  final merged = BenchmarkResult(
    label: label,
    timestamp: results.first.timestamp,
    series: series,
  );

  log.fine('Starting toBytes()');
  final benchmarkContents = merged.toBytes();
  log.finer('Finished toBytes()');

  final benchmarkFilename =
      path.withoutExtension(argResults.rest.first) + '-merged.benchmark';
  try {
    final file = File(benchmarkFilename);
    log.fine('Writing to $benchmarkFilename');
    await file.writeAsBytes(benchmarkContents);
    log.fine('Finished writing');
  } on FileSystemException catch (e) {
    stderr.writeln('ERROR: Could not write $benchmarkFilename');
    stderr.writeln('$e');
    return 1;
  }

  log.info('File ${path.basename(benchmarkFilename)} written.');

  return 0;
}

Logger log = Logger('benchmerge');
