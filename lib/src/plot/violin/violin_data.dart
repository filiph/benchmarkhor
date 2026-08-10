import 'dart:io';
import 'dart:math';

import 'package:benchmarkhor/src/plot/stats.dart';
import 'package:t_stats/t_stats.dart';

// ---------------------------------------------------------------------------
// Data for one violin
// ---------------------------------------------------------------------------

class ViolinData {
  final String label;
  final List<num> sorted;
  final Statistic stat;

  /// Box plot stats
  final double q1, median, q3, iqr;
  final double whiskerLo, whiskerHi;
  final List<double> outliers;

  /// KDE points
  final List<(double, double)> kdePoints;
  final double maxDensity;

  /// The maximum value this input wants to show on the y-axis.
  final double inputMax;

  ViolinData({
    required this.label,
    required this.sorted,
    required this.stat,
    required this.q1,
    required this.median,
    required this.q3,
    required this.iqr,
    required this.whiskerLo,
    required this.whiskerHi,
    required this.outliers,
    required this.kdePoints,
    required this.maxDensity,
    required this.inputMax,
  });

  factory ViolinData.compute(
    String label,
    List<num> values, {
    double maxOutlierCoefficient = 3.0,
  }) {
    if (values.isEmpty) {
      stderr.writeln('Warning: $label has no data.');
    }
    final sorted = List<num>.from(values)..sort((a, b) => a.compareTo(b));
    final stat = Statistic.from(sorted.map((v) => v.toDouble()).toList());

    final q1 = percentile(sorted, 0.25);
    final med = percentile(sorted, 0.50);
    final q3 = percentile(sorted, 0.75);
    final iqr = q3 - q1;

    final inputMax = med + maxOutlierCoefficient * iqr;

    final fenceLo = q1 - 1.5 * iqr;
    final fenceHi = q3 + 1.5 * iqr;

    final nonOutliers = sorted.where((v) => v >= fenceLo && v <= fenceHi);
    final whiskerLo =
        nonOutliers.isNotEmpty ? nonOutliers.first.toDouble() : q1;
    final whiskerHi = nonOutliers.isNotEmpty ? nonOutliers.last.toDouble() : q3;

    final outliers = sorted
        .where((v) => v < fenceLo || v > fenceHi)
        .map((v) => v.toDouble())
        .toList();

    // KDE over the non-outlier data range, truncated at whiskers.
    final nonOutlierList = nonOutliers.toList();
    final kdePoints = kde(nonOutlierList, whiskerLo, whiskerHi);
    final maxDensity =
        kdePoints.isEmpty ? 0.0 : kdePoints.map((p) => p.$2).reduce(max);

    return ViolinData(
      label: label,
      sorted: sorted,
      stat: stat,
      q1: q1,
      median: med,
      q3: q3,
      iqr: iqr,
      whiskerLo: whiskerLo,
      whiskerHi: whiskerHi,
      outliers: outliers,
      kdePoints: kdePoints,
      maxDensity: maxDensity,
      inputMax: inputMax,
    );
  }
}
