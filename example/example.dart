import 'dart:math';

import 'package:benchmarkhor/benchmark_result.dart';

/// This is an example of how to use this package programmatically.
/// You probably don't want to.
///
/// Read the `README` to learn how to use the command line tools
/// provided by this package instead.
void main() {
  // Just some random numbers. Pretend these are benchmark results.
  final measurements =
      List<int>.generate(10000, (index) => 1000 + _random.nextInt(4200));

  // If you believe you won't ever care about the order of the measurements,
  // it makes sense to sort them. This will make the .benchmark file
  // significantly smaller.
  measurements.sort();

  // Series is just a list of measurements with a label. They represent
  // one aspect of the performance of your app.
  // For example, these can be "build times" or "memory footprints".
  final series = MeasurementSeries(
    'build times',
    measurements,
  );

  // Benchmark result is a set of measurement series, with a label
  // and a timestamp.
  final result = BenchmarkResult(
    label: 'big refactoring',
    timestamp: DateTime.now().toUtc(),
    series: [series],
  );

  // Benchmark results can be serialized into a LZMA-compressed format.
  final bytes = result.toBytes();
  print('Saved in ${bytes.lengthInBytes} bytes');

  // You can save the data to a file.
  // File('test.benchmark').writeAsBytesSync(bytes);

  // Later, you can reload it.
  // final reloaded =
  //   BenchmarkResult.fromBytes(File('test.benchmark').readAsBytesSync());
}

final _random = Random();
