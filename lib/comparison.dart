import 'dart:math';

import 'package:benchmarkhor/benchmark_result.dart';
import 'package:logging/logging.dart';
import 'package:t_stats/t_stats.dart';

Logger _log = Logger('comparison');

class FlutterComparison {
  static const _fps120BudgetInMicroseconds = 1000000 / 120;
  static const _fps120Budget = _fps120BudgetInMicroseconds / 1000;

  /// Histogram always shows this range: ±8.0ms.
  ///
  /// That's a huge number, since an improvement by that much can easily
  /// erase all jank.
  static const _histogramRange = 8000;

  final BenchmarkResult original, improved;

  final List<int> _uiDiffs;
  final List<int> _rasterDiffs;

  final int _originalUiCount;
  final int _originalRasterCount;

  final int _improvedUiCount;
  final int _improvedRasterCount;

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
    BenchmarkResult original,
    BenchmarkResult improved,
    double frameBudget,
  ) {
    return FlutterComparison._(
      original,
      improved,
      _FlutterProfileBenchmarkResult(original),
      _FlutterProfileBenchmarkResult(improved),
      frameBudget: frameBudget,
    );
  }

  FlutterComparison._(
    this.original,
    this.improved,
    _FlutterProfileBenchmarkResult originalData,
    _FlutterProfileBenchmarkResult improvedData, {
    @Deprecated('do not use') this.runtimeThreshold = 0,
    this.frameBudget = _fps120Budget,
  })  : _uiDiffs = computeDiffs(
            originalData.uiTimes, improvedData.uiTimes, runtimeThreshold),
        _rasterDiffs = computeDiffs(originalData.rasterTimes,
            improvedData.rasterTimes, runtimeThreshold),
        _originalUiCount = originalData.uiTimes.length,
        _improvedUiCount = improvedData.uiTimes.length,
        _originalRasterCount = originalData.rasterTimes.length,
        _improvedRasterCount = improvedData.rasterTimes.length,
        _originalUiFullRuntime = originalData.uiTimes.fold(0, _sum),
        _improvedUiFullRuntime = improvedData.uiTimes.fold(0, _sum),
        _originalRasterFullRuntime = originalData.rasterTimes.fold(0, _sum),
        _improvedRasterFullRuntime = improvedData.rasterTimes.fold(0, _sum),
        _originalUiSkippedFrames =
            _countSkipped(originalData.uiTimes, frameBudget),
        _improvedUiSkippedFrames =
            _countSkipped(improvedData.uiTimes, frameBudget),
        _originalRasterSkippedFrames =
            _countSkipped(originalData.rasterTimes, frameBudget),
        _improvedRasterSkippedFrames =
            _countSkipped(improvedData.rasterTimes, frameBudget);

  String get asciiVisualizations {
    return '<-- (improvement)                  UI thread                (deterioration) -->\n\n'
        '${createAsciiVisualization(_uiDiffs)}\n\n'
        '<-- (improvement)                Raster thread              (deterioration) -->\n\n'
        '${createAsciiVisualization(_rasterDiffs)}';
  }

  String get report {
    final reportStats = _createReportStats();
    final uiReport = createReport(
        _uiDiffs,
        'UI',
        _originalUiCount,
        _improvedUiCount,
        _originalUiFullRuntime,
        _improvedUiFullRuntime,
        _originalUiSkippedFrames,
        _improvedUiSkippedFrames);
    final rasterReport = createReport(
        _rasterDiffs,
        'Raster',
        _originalRasterCount,
        _improvedRasterCount,
        _originalRasterFullRuntime,
        _improvedRasterFullRuntime,
        _originalRasterSkippedFrames,
        _improvedRasterSkippedFrames);
    return '$reportStats\n'
        '$uiReport\n'
        '$rasterReport';
  }

  String _createReportStats() {
    final buf = StringBuffer();

    void addStatsFor(String name, List<num> before, List<num> after) {
      buf.writeln('${name.padRight(8)} Median  Average');

      if (before.length / after.length < 0.7 ||
          after.length / before.length < 0.7) {
        _log.warning(
            'The two sets of measurement for "$name" are not the same length. '
            'Not even similar: ${before.length} versus ${after.length}.');
      }

      final beforeStats = Statistic.from(before);
      final afterStats = Statistic.from(after);

      void addLine(String label, List<num> measurements, Statistic stats) {
        buf.write('$label:'.padRight(8));
        buf.write(stats.median.toStringAsFixed(0).padLeft(7));
        buf.write(stats.mean.toStringAsFixed(1).padLeft(9));
        buf.writeln();
      }

      addLine('Before', before, beforeStats);
      addLine('After', after, afterStats);

      if (afterStats.isMeanDifferentFrom(beforeStats)) {
        buf.writeln('         '
            '* statistically significant difference (95% confidence)');
      } else {
        buf.writeln('         '
            '* not a statistically significant difference (95% confidence)');
      }
    }

    addStatsFor(
        'UI',
        original.series.singleWhere((s) => s.label == 'UI thread').measurements,
        improved.series
            .singleWhere((s) => s.label == 'UI thread')
            .measurements);
    addStatsFor(
        'Raster',
        original.series
            .singleWhere((s) => s.label == 'Raster thread')
            .measurements,
        improved.series
            .singleWhere((s) => s.label == 'Raster thread')
            .measurements);

    return buf.toString();
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
      int originalCount,
      int improvedCount,
      int originalRuntime,
      int improvedRuntime,
      int originalSkipped,
      int improvedSkipped) {
    final buf = StringBuffer();

    buf.writeln('$thread thread (N=$originalCount):');

    final runtimeDifference = improvedRuntime - originalRuntime;
    final gerund = runtimeDifference <= 0 ? 'improvement' : 'worsening';
    buf.writeln('* '
        '${(runtimeDifference.abs() / originalRuntime * 100).toStringAsFixed(1)}% '
        '(${(runtimeDifference / 1000).toStringAsFixed(0)}ms) '
        '$gerund of total execution time');

    final jankRiskRatio = RiskRatio.fromPrevalence(
        improvedCount, improvedSkipped, originalCount, originalSkipped);
    if (!jankRiskRatio.isSignificant) {
      buf.write('* No significant change in jank risk');
    } else if (jankRiskRatio.ratio < 1) {
      final smallerPercent = ((1 - jankRiskRatio.upper) * 100).round();
      final higherPercent = ((1 - jankRiskRatio.lower) * 100).round();
      buf.write('* -$smallerPercent% to -$higherPercent% less potential jank');
    } else {
      final smallerPercent = ((jankRiskRatio.lower - 1) * 100).round();
      final higherPercent = ((jankRiskRatio.upper - 1) * 100).round();
      buf.write('* +$smallerPercent to +$higherPercent% more potential jank');
    }
    final originalSkippedRatio =
        (originalSkipped / originalCount * 100).toStringAsFixed(1);
    final improvedSkippedRatio =
        (improvedSkipped / improvedCount * 100).toStringAsFixed(1);
    buf.writeln(' ($originalSkipped -> $improvedSkipped, '
        'or $originalSkippedRatio% -> $improvedSkippedRatio%)');

    final skippedDifference = improvedSkipped - originalSkipped;
    final skippedPpt =
        (improvedSkipped / improvedCount - originalSkipped / originalCount) *
            100;
    final noun = skippedDifference <= 0 ? 'decrease' : 'increase';
    buf.writeln('  ('
        "That's a ${skippedPpt.abs().toStringAsFixed(0)} ppt "
        '$noun in ratio of jank-to-normal frames.)');

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

/// Relative risk ratio with intervals
class RiskRatio {
  final double lower;
  final double upper;
  final double ratio;

  /// If `true`, the risk change is statistically significant.
  ///
  /// The "null value" (statistically speaking) is 1. If the confidence
  /// interval doesn't include 1, then the change is statistically significant.
  bool get isSignificant => lower > 1 || upper < 1;

  const RiskRatio(this.ratio, this.lower, this.upper);

  /// Standard computation according to:
  /// https://sphweb.bumc.bu.edu/otlt/mph-modules/bs/bs704_confidence_intervals/bs704_confidence_intervals8.html
  factory RiskRatio.fromPrevalence(
      int improvedTotalCount,
      int improvedWithOutcome,
      int originalTotalCount,
      int originalWithOutcome) {
    final n1 = improvedTotalCount;
    final x1 = improvedWithOutcome;
    final n2 = originalTotalCount;
    final x2 = originalWithOutcome;
    assert(n1 > 0);
    assert(x1 <= n1);
    assert(x1 > 0);
    assert(n2 > 0);
    assert(x2 <= n2);
    assert(x2 > 0);

    final p1 = x1 / n1;
    final p2 = x2 / n2;
    final rr = p1 / p2;

    /// 95% confidence z-score
    const z = 1.96;
    final c1 = ((n1 - x1) / x1) / n1;
    final c2 = ((n2 - x2) / x2) / n2;
    final c = z * sqrt(c1 + c2);
    final ln = log(rr);

    final lowerLn = ln - c;
    final upperLn = ln + c;

    final lower = exp(lowerLn);
    final upper = exp(upperLn);

    return RiskRatio(rr, lower, upper);
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

extension on Statistic {
  bool isMeanDifferentFrom(Statistic other) =>
      (other.lowerBound < lowerBound && other.upperBound < lowerBound) ||
      (other.lowerBound > upperBound && other.upperBound > upperBound);
}
