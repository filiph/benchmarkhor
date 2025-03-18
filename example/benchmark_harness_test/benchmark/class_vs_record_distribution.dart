import 'dart:io';
import 'dart:math' as math;

import 'package:t_stats/t_stats.dart';

import 'benchmark_base.dart';
import 'histogram_emitter.dart';

void main() async {
  // BaselineBenchmark().report();
  // ClassBenchmark().report();
  // RecordBenchmark().report();

  const exercises = 10000;
  const perExercise = 1;

  final record = await RecordBenchmark()
      .reportAsync(exercises: exercises, perExercise: perExercise);
  final baseline = await BaselineBenchmark()
      .reportAsync(exercises: exercises, perExercise: perExercise);
  final clazz = await ClassBenchmark()
      .reportAsync(exercises: exercises, perExercise: perExercise);

  print('five number summary');
  print(baseline.statistic.toFiveNumberSummary());
  print(clazz.statistic.toFiveNumberSummary());
  print(record.statistic.toFiveNumberSummary());
  print('p99');
  print(baseline.statistic.p99);
  print(clazz.statistic.p99);
  print(record.statistic.p99);
  print('p999');
  print(baseline.statistic.p999);
  print(clazz.statistic.p999);
  print(record.statistic.p999);
  final mannWhitney = MannWhitney.from(clazz.measurements, record.measurements);
  print('Class beats Record in: '
      '${((1 - mannWhitney.effectSize) * 100).toStringAsFixed(2)}%');

  final dataFile = File('data.txt');
  IOSink? output;
  try {
    output = dataFile.openWrite();
    output.writeln('baseline\tclass\trecord');
    for (var i = 0; i < baseline.measurements.length; i++) {
      output.writeln('${baseline.measurements[i]}\t'
          '${clazz.measurements[i]}\t'
          '${record.measurements[i]}');
    }
    print('Data in $dataFile.');
  } finally {
    output?.close();
  }

  final histogramFile = File('histogram_data.txt');
  IOSink? histogramOutput;
  try {
    histogramOutput = histogramFile.openWrite();
    final minValue = <double>[
      baseline.statistic.min.toDouble(),
      clazz.statistic.min.toDouble(),
      record.statistic.min.toDouble(),
    ].fold(double.infinity, (a, b) => math.min(a, b));
    final maxValue = <double>[
      baseline.statistic.max.toDouble(),
      clazz.statistic.max.toDouble(),
      record.statistic.max.toDouble(),
    ].fold(double.negativeInfinity, (a, b) => math.max(a, b));
    final rangeMax = maxValue;
    const bucketCount = 1000;
    const bandwidth = 0.5;
    final baselineHistogram = Histogram(baseline.measurements,
        forceRange: rangeMax, bucketCount: bucketCount, bandwidth: bandwidth);
    final baselineBuckets = baselineHistogram.bucketsNormalized;
    final clazzHistogram = Histogram(clazz.measurements,
        forceRange: rangeMax, bucketCount: bucketCount, bandwidth: bandwidth);
    final clazzBuckets = clazzHistogram.bucketsNormalized;
    final recordHistogram = Histogram(record.measurements,
        forceRange: rangeMax, bucketCount: bucketCount, bandwidth: bandwidth);
    final recordBuckets = recordHistogram.bucketsNormalized;

    histogramOutput.writeln('baseline\tclass\trecord');
    for (var i = 0; i < baselineBuckets.length; i++) {
      histogramOutput.writeln('${baselineBuckets[i]}\t'
          '${clazzBuckets[i]}\t'
          '${recordBuckets[i]}');
    }
    print('Histogram data in $histogramFile.');
  } finally {
    histogramOutput?.close();
  }

  exitCode = 0;
  return;
}

typedef MyRecord = ({double real, int integer, String string});

final class BaselineBenchmark extends _BaseBenchmark {
  late final List<int> _store = List.filled(count, 0);

  BaselineBenchmark() : super('Baseline');

  @override
  void run() {
    for (var i = 0; i < count; i++) {
      _store[i] = getInt();
    }
  }

  @override
  void teardown() {
    exitCode = _store.last;
  }
}

final class ClassBenchmark extends _BaseBenchmark {
  late final List<MyClass> _store =
      List.filled(count, MyClass(real: 0, integer: 0, string: ''));

  ClassBenchmark() : super('MyClass');

  @override
  void run() {
    for (var i = 0; i < count; i++) {
      _store[i] = getClass();
    }
  }

  @override
  void teardown() {
    exitCode = _store.last.integer;
  }
}

final class MyClass {
  final double real;
  final int integer;
  final String string;

  const MyClass(
      {required this.real, required this.integer, required this.string});
}

final class RecordBenchmark extends _BaseBenchmark {
  late final List<MyRecord> _store =
      List.filled(count, (real: 0, integer: 0, string: ''));

  RecordBenchmark() : super('MyRecord');

  @override
  void run() {
    for (var i = 0; i < count; i++) {
      _store[i] = getRecord();
    }
  }

  @override
  void teardown() {
    exitCode = _store.last.integer;
  }
}

sealed class _BaseBenchmark extends BenchmarkBase {
  final int count = 100000;

  int _counter = 0;

  _BaseBenchmark(super.name) : super(emitter: HistogramEmitter());

  @override
  void exercise() => run();

  MyClass getClass() => switch (_counter++ % 2) {
        0 => MyClass(real: 3.14, integer: 42, string: "hello"),
        1 => MyClass(real: -0.0, integer: 1337, string: "こんにちは世界"),
        _ => throw 'Unreachable',
      };

  int getInt() => switch (_counter++ % 2) {
        0 => 1,
        1 => 2,
        _ => throw 'Unreachable',
      };

  MyRecord getRecord() => switch (_counter++ % 2) {
        0 => (real: 3.14, integer: 42, string: "hello"),
        1 => (real: -0.0, integer: 1337, string: "こんにちは世界"),
        _ => throw 'Unreachable',
      };
}
