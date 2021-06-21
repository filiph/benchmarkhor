import 'dart:math';

import 'package:benchmarkhor/benchmark_result.dart';

class FlutterComparison {
  static const _120fpsBudgetInMicroseconds = 1000000 / 120;
  static const _120fpsBudget = _120fpsBudgetInMicroseconds / 1000;

  /// Histogram always shows this range: ±8.0ms.
  ///
  /// That's a huge number, since an improvement by that much can easily
  /// erase all jank.
  static const _histogramRange = 8000;

  final List<int> _uiTimes;
  final List<int> _rasterTimes;
  final int _originalUiFullRuntime;
  final int _improvedUiFullRuntime;

  final int _originalRasterFullRuntime;
  final int _improvedRasterFullRuntime;
  final double frameBudget;

  final int _originalUiSkippedFrames;
  final int _improvedUiSkippedFrames;
  final int _originalRasterSkippedFrames;
  final int _improvedRasterSkippedFrames;

  /// The comparison will ignore measurements that are less than this
  /// long (in microseconds).
  final int runtimeThreshold;

  factory FlutterComparison(
      BenchmarkResult original, BenchmarkResult improved) {
    return FlutterComparison._(
      _FlutterProfileBenchmarkResult(original),
      _FlutterProfileBenchmarkResult(improved),
    );
  }

  FlutterComparison._(
    _FlutterProfileBenchmarkResult original,
    _FlutterProfileBenchmarkResult improved, {
    @deprecated this.runtimeThreshold = 0,
    this.frameBudget = _120fpsBudget,
  })  : _uiTimes =
            computeDiffs(original.uiTimes, improved.uiTimes, runtimeThreshold),
        _rasterTimes = computeDiffs(
            original.rasterTimes, improved.rasterTimes, runtimeThreshold),
        _originalUiFullRuntime = original.uiTimes.fold(0, _sum),
        _improvedUiFullRuntime = improved.uiTimes.fold(0, _sum),
        _originalRasterFullRuntime = original.rasterTimes.fold(0, _sum),
        _improvedRasterFullRuntime = improved.rasterTimes.fold(0, _sum),
        _originalUiSkippedFrames = _countSkipped(original.uiTimes, frameBudget),
        _improvedUiSkippedFrames = _countSkipped(improved.uiTimes, frameBudget),
        _originalRasterSkippedFrames =
            _countSkipped(original.rasterTimes, frameBudget),
        _improvedRasterSkippedFrames =
            _countSkipped(improved.rasterTimes, frameBudget);

  String get asciiVisualizations {
    return '<-- (improvement)                  UI thread                (deterioration) -->\n\n'
        '${createAsciiVisualization(_uiTimes)}\n\n'
        '<-- (improvement)                Raster thread              (deterioration) -->\n\n'
        '${createAsciiVisualization(_rasterTimes)}';
  }

  String get report {
    final uiReport = createReport(
        _uiTimes,
        'UI',
        _originalUiFullRuntime,
        _improvedUiFullRuntime,
        _originalUiSkippedFrames,
        _improvedUiSkippedFrames);
    final rasterReport = createReport(
        _rasterTimes,
        'Raster',
        _originalRasterFullRuntime,
        _improvedRasterFullRuntime,
        _originalRasterSkippedFrames,
        _improvedRasterSkippedFrames);
    return '$uiReport\n'
        '$rasterReport';
  }

  static List<int> computeDiffs(
      List<int> original, List<int> improved, int threshold) {
    final originalOrdered =
        List<int>.from(original.where((m) => m > threshold), growable: false)
          ..sort();
    final improvedOrdered =
        List<int>.from(improved.where((m) => m > threshold), growable: false)
          ..sort();
    final length = min(originalOrdered.length, improvedOrdered.length);

    return List<int>.generate(length, (index) {
      // Take two measurements that are at the same position
      // in the sorted lists.
      final measurementOriginal =
          originalOrdered[(index / length * originalOrdered.length).round()];
      final measurementImproved =
          improvedOrdered[(index / length * improvedOrdered.length).round()];
      return measurementImproved - measurementOriginal;
    });
  }

  static String createAsciiVisualization(List<int> measurements) {
    final buf = StringBuffer();

    final histogram = Histogram(measurements, forceRange: _histogramRange);

    // We want a bucket for the exact middle of the range.
    assert(Histogram.bucketCount.isOdd);
    // Number of characters on each side of the center line.
    const sideSize = (Histogram.bucketCount - 1) ~/ 2;

    // How many characters should the largest bucket be high?
    const height = 20;

    for (var row = 1; row <= height; row++) {
      for (var column = 0; column < Histogram.bucketCount; column++) {
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

    buf.writeln('─' * Histogram.bucketCount);

    final boundValueString =
        '${(histogram.lowestBound / 1000).abs().toStringAsFixed(1)}ms';

    buf.writeln('-${boundValueString.padRight(sideSize - 1)}'
        '^'
        '${boundValueString.padLeft(sideSize)}');

    return buf.toString();
  }

  static String createReport(
      List<int> measurements,
      String thread,
      int originalRuntime,
      int improvedRuntime,
      int originalSkipped,
      int improvedSkipped) {
    final buf = StringBuffer();

    buf.writeln('$thread thread:');

    final runtimeDifference = improvedRuntime - originalRuntime;
    final gerund = runtimeDifference <= 0 ? 'improvement' : 'worsening';
    buf.writeln('* '
        '${(runtimeDifference.abs() / originalRuntime * 100).toStringAsFixed(1)}% '
        '(${(runtimeDifference / 1000).toStringAsFixed(0)}ms) '
        '$gerund of total execution time');

    final skippedDifference = improvedSkipped - originalSkipped;
    final skippedPpt = (improvedSkipped / measurements.length -
            originalSkipped / measurements.length) *
        100;
    final noun = skippedDifference <= 0 ? 'decrease' : 'increase';
    buf.writeln('* '
        '${skippedPpt.abs().toStringAsFixed(0)} ppt $noun in potential jank '
        '($originalSkipped -> $improvedSkipped)');

    // final betterMeasurements = measurements.where((m) => m < 0).length;
    // final betterPercent = (betterMeasurements / measurements.length) * 100;
    // buf.writeln('* ${betterPercent.toStringAsFixed(2)}% of times are improved');

    // 833 microseconds is 5% of a 60fps frame budget
    // 1000 microseconds is 6% of a 60fps frame budget
    const threshold = 1000;
    final betterMeasurementsWithPadding =
        measurements.where((m) => m < -threshold).length;
    final betterPercentWithPadding =
        (betterMeasurementsWithPadding / measurements.length) * 100;
    buf.writeln('* ${betterPercentWithPadding.toStringAsFixed(1)}% '
        'of individual measurements improved by 1ms+');

    final worseMeasurementsWithPadding =
        measurements.where((m) => m > threshold).length;
    final worsePercentWithPadding =
        (worseMeasurementsWithPadding / measurements.length) * 100;
    buf.writeln('* ${worsePercentWithPadding.toStringAsFixed(1)}% '
        'of individual measurements worsened by 1ms+');

    return buf.toString();
  }

  static int _countSkipped(Iterable<int> measurements, double threshold) =>
      measurements.where((m) => m > threshold * 1000).length;

  static int _sum(int a, int b) => a + b;
}

/// A histogram around 0.
class Histogram {
  static const bucketCount = 79;
  static const sideSize = (bucketCount - 1) ~/ 2;
  final bucketMemberCounts = List<int>.filled(bucketCount, 0);
  late final List<double> bucketsNormalized;
  late final double lowestBound;

  // The width is 79 characters (so that there's a center line,
  // and so that it covers a standard 80-wide terminal).
  late final double highestBound;
  // Number of characters on each side of the center line.
  late final double bucketWidth;

  /// Creates a histogram from a list of [measurements].
  ///
  /// If [forceRange] is specified, the histogram will only span from `-x`
  /// to `+x`, exactly. The measurements that fall outside this range will be
  /// added to the outermost buckets.
  Histogram(List<int> measurements, {int? forceRange}) {
    // Maximum distance from 0.
    var distance = forceRange ??
        measurements.fold<int>(
            0, (previousValue, element) => max(previousValue, element.abs()));

    lowestBound = (-distance - 1);
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

class _FlutterProfileBenchmarkResult {
  final List<int> uiTimes;
  final List<int> rasterTimes;

  _FlutterProfileBenchmarkResult(BenchmarkResult result)
      : assert(result.type == 'flutter-profile '),
        uiTimes = result.series
            .where((s) => s.label == 'UI thread')
            .single
            .measurements,
        rasterTimes = result.series
            .where((s) => s.label == 'Raster thread')
            .single
            .measurements;
}
