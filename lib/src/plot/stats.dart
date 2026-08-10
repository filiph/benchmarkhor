import 'dart:math';

import 'package:t_stats/t_stats.dart';

/// Returns the p-th percentile (0..1) of a *sorted* list using linear
/// interpolation (same as numpy default / R type 7).
double percentile(List<num> sorted, double p) {
  if (sorted.isEmpty) return 0;
  if (sorted.length == 1) return sorted[0].toDouble();
  final index = p * (sorted.length - 1);
  final lo = index.floor();
  final hi = index.ceil();
  if (lo == hi) return sorted[lo].toDouble();
  final frac = index - lo;
  return sorted[lo] * (1 - frac) + sorted[hi] * frac;
}

// ---------------------------------------------------------------------------
// KDE
// ---------------------------------------------------------------------------

/// Gaussian kernel density estimate.  Returns a list of [n] (y, density)
/// pairs spanning [yMin, yMax].  Uses Silverman's rule of thumb for
/// bandwidth unless [bwOverride] is provided.
List<(double, double)> kde(
  List<num> sorted,
  double yMin,
  double yMax, {
  int n = 200,
  double? bwOverride,
}) {
  if (sorted.isEmpty) return [];
  final vals = sorted.map((v) => v.toDouble()).toList();
  final stat = Statistic.from(vals);
  final stdDev = stat.stdDeviation.toDouble();
  // Silverman's rule of thumb
  double bw = bwOverride ?? (1.06 * stdDev * pow(vals.length, -0.2));
  if (bw == 0) bw = 1.0; // Avoid division by zero
  final bw2 = bw * bw;
  const invSqrt2pi = 0.3989422804014327; // 1/sqrt(2π)

  final result = <(double, double)>[];
  final step = (yMax - yMin) / (n - 1);
  for (int i = 0; i < n; i++) {
    final y = yMin + i * step;
    double density = 0;
    for (final v in vals) {
      final diff = y - v;
      density += invSqrt2pi / bw * exp(-0.5 * diff * diff / bw2);
    }
    density /= vals.length;
    result.add((y, density));
  }
  return result;
}
