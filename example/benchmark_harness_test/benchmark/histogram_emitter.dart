import 'dart:math' as math;

import 'package:t_stats/t_stats.dart';

import 'benchmark_result.dart';
import 'find_peaks.dart';
import 'score_emitter.dart';

final class HistogramEmitter extends ScoreEmitter {
  @override
  void emit(String testName, BenchmarkResult result,
      {String metric = 'RunTime', String unit = 'us'}) {
    print(_createAsciiVisualization(result.measurements));
    print('Ran ${result.exercisesCount} exercises, '
        '${result.iterationsPerExercise} iterations per exercise.');
    print(ShapiroWilk.from(result.measurements).describe());
    print(result.statistic);
    print(ShapiroWilk.from(result.measurements.map((n) => math.log(n)))
        .describe());
    print(result.statisticLogNormal);

    final cv = result.statistic.coefficientOfVariation;
    print('    Coefficient of variation: ${(cv * 100).toStringAsFixed(2)}%');
    final logCv = result.statisticLogNormal.coefficientOfVariation;
    print('Log coefficient of variation: ${(logCv * 100).toStringAsFixed(2)}%');
  }

  static String _createAsciiVisualization(Iterable<double> measurements) {
    final buf = StringBuffer();

    final histogram = Histogram(measurements);

    // We want a bucket for the exact middle of the range.
    assert(histogram.bucketCount.isOdd);
    // Number of characters on each side of the center line.
    final sideSize = (histogram.bucketCount - 1) ~/ 2;

    // How many characters should the largest bucket be high?
    const height = 10;

    for (var row = 1; row <= height; row++) {
      for (var column = 0; column < histogram.bucketCount; column++) {
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

    buf.writeln('─' * histogram.bucketCount);

    String formatBound(double value) =>
        '${(value / 1000).abs().toStringAsFixed(1)}ms';

    buf.writeln('${formatBound(histogram.lowestBound).padRight(sideSize - 1)}'
        '^'
        '${formatBound(histogram.highestBound).padLeft(sideSize)}');

    buf.writeln();

    for (final peak in histogram.peaks) {
      buf.writeln('Peak: ${peak.$1} at ${peak.$2}');
    }

    return buf.toString();
  }
}

/// A histogram.
class Histogram {
  static const defaultBucketCount = 79;

  late final bucketMemberCounts = List<int>.filled(bucketCount, 0);

  late final List<double> bucketsNormalized;

  late final double lowestBound;

  late final double highestBound;

  late final List<(Peak, double)> peaks;

  final int bucketCount;

  /// Creates a histogram from a list of [measurements].
  ///
  /// If [forceRange] is specified, the histogram will only span from `-x`
  /// to `+x`, exactly. The measurements that fall outside this range will be
  /// added to the outermost buckets.
  Histogram(
    Iterable<double> measurements, {
    double? forceRange,
    this.bucketCount = defaultBucketCount,
    double? bandwidth,
  }) {
    // // Maximum distance from 0.
    // var distance = forceRange ??
    //     measurements.fold<double>(
    //         0, (previousValue, element) => max(previousValue, element.abs()));
    //
    // lowestBound = 0;
    // highestBound = (distance + 1);
    //
    // bucketWidth = (highestBound - lowestBound) / bucketCount;
    //
    // for (final m in measurements) {
    //   var bucketIndex = ((m - lowestBound) / bucketWidth).floor();
    //   if (bucketIndex < 0) {
    //     assert(forceRange != null);
    //     bucketIndex = 0;
    //   }
    //   if (bucketIndex >= bucketCount) {
    //     assert(forceRange != null);
    //     bucketIndex = bucketCount - 1;
    //   }
    //   bucketMemberCounts[bucketIndex] += 1;
    // }
    //
    // final highestCount = bucketMemberCounts.fold<int>(0, max);
    // bucketsNormalized = List<double>.generate(
    //     bucketCount, (index) => bucketMemberCounts[index] / highestCount);
    //
    // // TODO: detect peaks: https://www.sthu.org/blog/13-perstopology-peakdetection/index.html
    // //   maybe back in t_stats?

    final statistic = Statistic.from(measurements);
    final stdDev = statistic.stdDeviation;

    // Default bandwidth using Silverman's rule
    final iqr = statistic.p75 - statistic.p25;
    bandwidth ??= 0.9 *
        math.min(stdDev, iqr / 1.34) *
        math.pow(measurements.length, -1 / 5);

    double min = measurements.fold(
        double.infinity, (prev, next) => math.min(prev, next));
    var max = measurements.fold(
        double.negativeInfinity, (prev, next) => math.max(prev, next));
    var range = max - min;

    // Add padding.
    min -= range * 0.1;
    max += range * 0.1;

    // HACK: reset min to 0 and max to forceRange -- for now
    min = 0;
    if (forceRange != null) max = forceRange;

    final points = bucketCount;
    List<_KdePoint> densityCurve = [];
    double step = (max - min) / (points - 1);

    double kernelFunction(double u) {
      // Epanechnikov (parabolic) kernel.
      // https://en.wikipedia.org/wiki/Kernel_(statistics)#Kernel_functions_in_common_use
      if (u.abs() > 1) return 0;
      return 3 / 4 * (1 - u * u);
    }

    for (int i = 0; i < points; i++) {
      double x = min + i * step;
      double density = 0;

      // Apply kernel to each data point
      for (double value in measurements) {
        density += kernelFunction((x - value) / bandwidth);
      }

      density *= 1 / (measurements.length * bandwidth);
      densityCurve.add(_KdePoint(x, density));
    }

    lowestBound = min;
    highestBound = max;

    final maxDensity = densityCurve.fold(
        double.negativeInfinity, (prev, next) => math.max(prev, next.density));
    bucketsNormalized =
        densityCurve.map((p) => p.density / maxDensity).toList(growable: false);

    // Find peaks.
    final peaks = getPersistentHomology(bucketsNormalized);
    this.peaks = peaks.map<(Peak, double)>((p) {
      final position = p.index / (bucketCount - 1);
      return (p, getValueFromPosition(position));
    }).toList(growable: false);
  }

  /// Returns the value represented by the [position] on the histogram.
  ///
  /// For example, if [lowestBound] is 0 and [highestBound] is 100, then
  /// the value at position 0.5 will be 50.
  double getValueFromPosition(double position) {
    if (position < 0) throw ArgumentError.value(position);
    if (position > 1) throw ArgumentError.value(position);

    return lowestBound + (highestBound - lowestBound) * position;
  }
}

class _KdePoint {
  final double value;
  final double density;
  const _KdePoint(this.value, this.density);
}
