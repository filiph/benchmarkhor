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

  final comparison = FlutterComparison(original, improved);

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
