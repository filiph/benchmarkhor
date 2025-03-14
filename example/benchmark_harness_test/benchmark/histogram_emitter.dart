import 'dart:math';

import 'benchmark_result.dart';
import 'score_emitter.dart';

final class HistogramEmitter extends ScoreEmitter {
  @override
  void emit(String testName, BenchmarkResult result,
      {String metric = 'RunTime', String unit = 'us'}) {
    print(_createAsciiVisualization(result.measurements));
    print('Ran ${result.exercisesCount} exercises, '
        '${result.iterationsPerExercise} iterations per exercise.');
    print(result.statistic.toString());

    // https://en.wikipedia.org/wiki/Coefficient_of_variation
    final cv = result.statistic.stdDeviation / result.statistic.mean;
    print('Coefficient of variation: ${(cv * 100).toStringAsFixed(2)}%');
  }

  static String _createAsciiVisualization(List<int> measurements) {
    final buf = StringBuffer();

    final histogram = _Histogram(measurements);

    // We want a bucket for the exact middle of the range.
    assert(_Histogram.bucketCount.isOdd);
    // Number of characters on each side of the center line.
    const sideSize = (_Histogram.bucketCount - 1) ~/ 2;

    // How many characters should the largest bucket be high?
    const height = 20;

    for (var row = 1; row <= height; row++) {
      for (var column = 0; column < _Histogram.bucketCount; column++) {
        final value = histogram.bucketsNormalized[column];
        if (value > (height - row + 0.5) / height) {
          // Definitely above the line.
          buf.write('█');
        } else if (value > (height - row + 0.05) / height) {
          // Meaningfully above the line.
          buf.write('▄');
        } else if (value > (height - row) / height && row == height) {
          // A tiny bit above the line, and also at the very bottom
          // of the graph (just above the axis). We show a dot here so that
          // this information isn't completely lost, even if it was just
          // one measurement.
          buf.write('.');
        } else {
          buf.write(' ');
        }
      }
      buf.writeln();
    }

    buf.writeln('─' * _Histogram.bucketCount);

    String formatBound(double value) =>
        '${(value / 1000).abs().toStringAsFixed(1)}ms';

    buf.writeln('${formatBound(histogram.lowestBound).padRight(sideSize - 1)}'
        '^'
        '${formatBound(histogram.highestBound).padLeft(sideSize)}');

    return buf.toString();
  }
}

/// A histogram around 0.
class _Histogram {
  static const bucketCount = 59;
  static const sideSize = (bucketCount - 1) ~/ 2;
  final bucketMemberCounts = List<int>.filled(bucketCount, 0);
  late final List<double> bucketsNormalized;
  late final double lowestBound;

  late final double highestBound;
  // Number of characters on each side of the center line.
  late final double bucketWidth;

  /// Creates a histogram from a list of [measurements].
  ///
  /// If [forceRange] is specified, the histogram will only span from `-x`
  /// to `+x`, exactly. The measurements that fall outside this range will be
  /// added to the outermost buckets.
  _Histogram(List<int> measurements, {int? forceRange}) {
    // Maximum distance from 0.
    var distance = forceRange ??
        measurements.fold<int>(
            0, (previousValue, element) => max(previousValue, element.abs()));

    lowestBound = 0;
    highestBound = (distance + 1);

    bucketWidth = (highestBound - lowestBound) / bucketCount;

    for (final m in measurements) {
      var bucketIndex = ((m - lowestBound) / bucketWidth).floor();
      if (bucketIndex < 0) {
        assert(forceRange != null);
        bucketIndex = 0;
      }
      if (bucketIndex >= bucketCount) {
        assert(forceRange != null);
        bucketIndex = bucketCount - 1;
      }
      bucketMemberCounts[bucketIndex] += 1;
    }

    final highestCount = bucketMemberCounts.fold<int>(0, max);
    bucketsNormalized = List<double>.generate(
        bucketCount, (index) => bucketMemberCounts[index] / highestCount);
  }
}
