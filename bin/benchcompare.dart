import 'dart:io';

import 'package:args/args.dart';
import 'package:benchmarkhor/benchmark_result.dart';
import 'package:benchmarkhor/comparison.dart';
import 'package:logging/logging.dart';

import 'src/read_benchmark_file.dart';

Future<int> main(List<String> args) async {
  final parser = ArgParser();
  parser.addFlag('help', abbr: 'h', help: 'Show help.', defaultsTo: false);
  parser.addFlag('verbose',
      abbr: 'v', help: 'Verbose output', defaultsTo: false);
  parser.addOption(
    'threshold',
    abbr: 't',
    help: 'The threshold in milliseconds above which '
        'a build time is considered over budget (a skipped frame). '
        'Defaults to ~8.333 (which is 1/120th of a second).',
    defaultsTo: (1000 / 120).toString(),
  );
  var argResults = parser.parse(args);

  if (argResults['verbose']) {
    Logger.root.level = Level.ALL;
  } else {
    Logger.root.level = Level.INFO;
  }

  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.message}');
  });

  if (argResults['help'] || argResults.rest.length != 2) {
    print('Compares two .benchmark files.\n'
        '\n'
        'Usage:\n'
        '\tbenchcompare baseline.benchmark improved.benchmark\n'
        '\n');
    print(parser.usage);
    return 2;
  }

  double? frameBudget;
  frameBudget = double.tryParse(argResults.option('threshold') ?? 'N/A');
  if (frameBudget == null) {
    stderr
        .writeln('ERROR: Threshold must be a parseable floating point number. '
            'Instead got: "${argResults['threshold']}".');
    return 1;
  }

  BenchmarkResult original, improved;
  try {
    original = await readFromFile(argResults.rest.first);
    improved = await readFromFile(argResults.rest.last);
  } on FileSystemException catch (e) {
    stderr.writeln('ERROR: Could not read one of the files');
    stderr.writeln('$e');
    return 1;
  } on LoadException catch (e) {
    stderr.writeln('ERROR: Could not read one of the files');
    stderr.writeln('$e');
    return 1;
  }

  final comparison = FlutterComparison(
    original,
    improved,
    frameBudget,
  );

  // print(comparison.uiDifferences);
  // print(comparison.rasterDifferences);
  // print('details');
  // print(comparison.uiDifferences.toTSV());
  // print(comparison.rasterDifferences.toTSV());
  print(comparison.asciiVisualizations);
  print(comparison.report);

  return 0;
}

Logger log = Logger('benchcompare');
