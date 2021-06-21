import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:benchmarkhor/benchmark_result.dart';
import 'package:benchmarkhor/extract.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

Future<int> main(List<String> args) async {
  final parser = ArgParser();
  parser.addOption(
    'type',
    help: 'Extract data into result type',
    allowedHelp: {
      'flutter-profile': 'Flutter profile',
    },
    defaultsTo: 'flutter-profile',
  );
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
  var argResults = parser.parse(args);

  if (argResults['verbose']) {
    Logger.root.level = Level.ALL;
  } else {
    Logger.root.level = Level.INFO;
  }

  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });

  if (argResults['help'] || argResults.rest.isEmpty) {
    print('Extracts measurements from timeline JSON files '
        'into .benchmark files.\n'
        '\n'
        'Usage:');
    print(parser.usage);
    return 2;
  }

  final type = argResults['type'];
  log.fine('Using benchmark type: `$type`');

  bool shouldSortMeasurements;
  if (argResults['sort'] == null) {
    if (type == 'flutter-profile') {
      shouldSortMeasurements = true;
    } else {
      shouldSortMeasurements = false;
    }
  } else {
    shouldSortMeasurements = argResults['sort'];
  }
  log.fine('Sorting ${shouldSortMeasurements ? 'enabled' : 'disabled'}');

  for (final filename in argResults.rest) {
    log.info('Extracting $filename');
    final label = path.basenameWithoutExtension(filename);

    String data;
    DateTime lastModified;
    try {
      final file = File(filename);
      data = await file.readAsString();
      log.fine('Finished reading $file');
      lastModified = (await file.lastModified()).toUtc();
      log.finer('Finished getting last modified: $lastModified');
    } on FileSystemException catch (e) {
      stderr.writeln('ERROR: Could not read $filename');
      stderr.writeln('$e');
      return 1;
    }

    log.fine('Starting extraction');
    BenchmarkResult result;
    try {
      result = await extractStatsFromFlutterTimeline(label, lastModified, data,
          shouldSort: shouldSortMeasurements);
    } on FormatException catch (e) {
      stderr.writeln('ERROR: Problem parsing $filename');
      stderr.writeln('$e');
      return 1;
    }
    log.finer('Finished extraction');

    for (final serie in result.series) {
      final n = serie.measurements.length;
      final minimum = serie.measurements.fold<int>(0xFFFFFFF, min);
      final maximum = serie.measurements.fold<int>(-0xFFFFFFF, max);
      int? median;
      if (shouldSortMeasurements) {
        median = serie.measurements[serie.measurements.length ~/ 2];
      }

      log.info('* ${serie.label}: '
          'N=$n, median=$median, min=$minimum, max=$maximum');
    }

    log.fine('Starting toBytes()');
    final benchmarkContents = result.toBytes();
    log.finer('Finished toBytes()');

    final benchmarkFilename = path.setExtension(filename, '.benchmark');
    try {
      final file = File(benchmarkFilename);
      log.fine('Writing to $benchmarkFilename');
      await file.writeAsBytes(benchmarkContents);
      log.fine('Finished writing');
    } on FileSystemException catch (e) {
      stderr.writeln('ERROR: Could not write $filename');
      stderr.writeln('$e');
      return 1;
    }

    log.info('File ${path.basename(benchmarkFilename)} written.');
  }

  return 0;
}

Logger log = Logger('benchextract');
