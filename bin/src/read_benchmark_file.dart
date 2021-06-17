import 'dart:io';

import 'package:benchmarkhor/benchmark_result.dart';
import 'package:logging/logging.dart';

Logger log = Logger('read_benchmark_file');

Future<BenchmarkResult> readFromFile(String filename) async {
  log.fine('Extracting $filename');

  final file = File(filename);
  final data = await file.readAsBytes();
  log.fine('Finished reading $file');

  log.fine('Loading');
  final result = BenchmarkResult.fromBytes(data);
  log.finer('Finished loading');

  return result;
}
