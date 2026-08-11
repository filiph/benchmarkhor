import 'dart:math' as math;

import 'package:benchmarkhor/src/plot/svg.dart';

// ---------------------------------------------------------------------------
// Y axis
// ---------------------------------------------------------------------------

/// The vertical axis shared by all plot types.
///
/// Encapsulates zero anchoring (the axis always contains 0), axis padding
/// (5% of the plot range, added only to an end that isn't zero) and the
/// extension of the axis so that it encompasses all its ticks.
class YAxis {
  /// Fraction of the plot range added as padding to a non-zero end.
  static const double paddingFraction = 0.05;

  /// The lowest value visible on the axis.
  final double min;

  /// The highest value visible on the axis.
  final double max;

  /// The values at which ticks (and grid lines) are drawn.
  final List<double> ticks;

  YAxis._(this.min, this.max, this.ticks);

  /// Builds an axis able to show everything between [rangeMin] and [rangeMax].
  factory YAxis.forRange(
    double rangeMin,
    double rangeMax, {
    int targetTickCount = 7,
  }) {
    // Zero anchoring: the axis always contains 0.
    var lo = math.min(rangeMin, 0.0);
    var hi = math.max(rangeMax, 0.0);

    // Degenerate input (no data, or all values exactly 0).
    if (hi - lo == 0) hi = 1;

    // Axis padding: only an end that isn't zero gets padding.
    final padding = (hi - lo) * paddingFraction;
    if (lo < 0) lo -= padding;
    if (hi > 0) hi += padding;

    final ticks = niceTicks(lo, hi, targetCount: targetTickCount);
    // Extend the axis to encompass the outermost ticks.
    return YAxis._(
      math.min(lo, ticks.first),
      math.max(hi, ticks.last),
      ticks,
    );
  }

  /// Maps a data value to an SVG pixel y coordinate (inverted: larger values
  /// map to smaller pixel coordinates).
  double toSvgY(double y) {
    return marginTop + plotHeight * (1 - (y - min) / (max - min));
  }

  /// Whether zero is visible on this axis. Always true in practice, but
  /// guards the drawing code against degenerate input.
  bool get containsZero => min <= 0 && 0 <= max;
}
