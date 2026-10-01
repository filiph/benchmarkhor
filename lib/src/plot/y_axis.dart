import 'dart:math' as math;

import 'package:benchmarkhor/src/plot/plot_unit.dart';
import 'package:benchmarkhor/src/plot/svg.dart';

// ---------------------------------------------------------------------------
// Y axis
// ---------------------------------------------------------------------------

/// The vertical axis shared by all plot types.
///
/// Encapsulates baseline anchoring (the axis always contains the baseline value),
/// axis padding (5% of the plot range, added only to an end that isn't the baseline)
/// and the extension of the axis so that it encompasses all its ticks.
class YAxis {
  /// Fraction of the plot range added as padding to a non-zero end.
  static const double paddingFraction = 0.05;

  /// The lowest value visible on the axis.
  final double min;

  /// The highest value visible on the axis.
  final double max;

  /// The values at which ticks (and grid lines) are drawn.
  final List<double> ticks;

  /// The layout geometry used by this axis.
  final PlotLayout layout;

  /// The unit interpretation for values on this axis.
  final PlotUnit unit;

  YAxis._(
    this.min,
    this.max,
    this.ticks, {
    this.layout = const PlotLayout(),
    this.unit = PlotUnit.microseconds,
  });

  /// Builds an axis able to show everything between [rangeMin] and [rangeMax].
  factory YAxis.forRange(
    double rangeMin,
    double rangeMax, {
    int targetTickCount = 7,
    PlotLayout layout = const PlotLayout(),
    PlotUnit unit = PlotUnit.microseconds,
  }) {
    // Baseline anchoring: the axis always contains the baseline value.
    final baseline = unit.baseline;
    var lo = math.min(rangeMin, baseline);
    var hi = math.max(rangeMax, baseline);

    // Degenerate input (no data, or all values exactly baseline).
    if (hi - lo == 0) hi = baseline + (unit == PlotUnit.ratio ? 0.1 : 1.0);

    // Axis padding: only an end that isn't the baseline gets padding.
    final padding = (hi - lo) * paddingFraction;
    if (lo < baseline) lo -= padding;
    if (hi > baseline) hi += padding;

    final ticks = niceTicks(lo, hi, targetCount: targetTickCount);
    // Extend the axis to encompass the outermost ticks.
    return YAxis._(
      math.min(lo, ticks.first),
      math.max(hi, ticks.last),
      ticks,
      layout: layout,
      unit: unit,
    );
  }

  /// Maps a data value to an SVG pixel y coordinate (inverted: larger values
  /// map to smaller pixel coordinates).
  double toSvgY(double y) {
    return layout.marginTop + layout.plotHeight * (1 - (y - min) / (max - min));
  }

  /// Whether the baseline is visible on this axis.
  bool get containsBaseline => min <= unit.baseline && unit.baseline <= max;

  /// Whether zero is visible on this axis. Always true in practice, but
  /// guards the drawing code against degenerate input.
  bool get containsZero => min <= 0 && 0 <= max;
}
