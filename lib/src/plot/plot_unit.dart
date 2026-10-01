import 'package:benchmarkhor/src/plot/svg.dart';

/// Defines how numeric data in a benchmark plot should be interpreted and formatted.
enum PlotUnit {
  microseconds('microseconds', baseline: 0.0),
  ratio('ratio', baseline: 1.0);

  final String name;
  final double baseline;

  const PlotUnit(this.name, {required this.baseline});

  static PlotUnit fromString(String value) {
    for (final unit in values) {
      if (unit.name == value) return unit;
    }
    throw ArgumentError.value(value, 'unit', 'Unsupported unit');
  }

  /// Formats a numeric value according to this unit's display rules.
  String formatValue(double v) {
    switch (this) {
      case PlotUnit.microseconds:
        return formatTick(v);
      case PlotUnit.ratio:
        final delta = (v - 1.0) * 100.0;
        final rounded = double.parse(delta.toStringAsFixed(1));
        if (rounded == 0.0) {
          return '0.0%';
        }
        final prefix = rounded > 0 ? '+' : '';
        return '$prefix${delta.toStringAsFixed(1)}%';
    }
  }
}
