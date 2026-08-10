import 'dart:math';

// ---------------------------------------------------------------------------
// Nice tick generation
// ---------------------------------------------------------------------------

/// Compute "nice" tick positions for an axis spanning [lo, hi].
/// Aims for roughly [targetCount] ticks.
List<double> niceTicks(double lo, double hi, {int targetCount = 6}) {
  if (hi <= lo) return [lo];
  final range = hi - lo;
  // Raw step
  final rawStep = range / targetCount;
  // Magnitude
  final mag = pow(10, (log(rawStep) / ln10).floor()).toDouble();
  // Normalised step
  final norm = rawStep / mag;
  // Round to nice normalised step
  double niceNorm;
  if (norm < 1.5) {
    niceNorm = 1;
  } else if (norm < 3) {
    niceNorm = 2;
  } else if (norm < 7) {
    niceNorm = 5;
  } else {
    niceNorm = 10;
  }
  final step = niceNorm * mag;
  final start = (lo / step).ceil() * step;
  final ticks = <double>[];
  var v = start;
  while (v <= hi + step * 1e-9) {
    ticks.add(v);
    v += step;
  }
  return ticks;
}

// ---------------------------------------------------------------------------
// SVG builder
// ---------------------------------------------------------------------------

class SvgBuffer {
  final _buf = StringBuffer();

  void write(String s) => _buf.write(s);
  void writeln(String s) => _buf.writeln(s);

  @override
  String toString() => _buf.toString();
}

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

const double svgWidth = 900;
const double svgHeight = 700;
const double marginLeft = 80;
const double marginRight = 40;
const double marginTop = 40;
const double marginBottom = 50;
const double plotWidth = svgWidth - marginLeft - marginRight;
const double plotHeight = svgHeight - marginTop - marginBottom;

// ---------------------------------------------------------------------------
// Shared color palette
// ---------------------------------------------------------------------------

const colors = [
  '#8033bbbb', // teal
  '#80bbaa44', // yellow-green
  '#8066aaee', // blue
  '#80ee8844', // orange
  '#80bb44aa', // pink
  '#8044bb66', // green
  '#80eeaa44', // amber
  '#80aa44ee', // purple
];

/// Format a tick value: if it's a whole number, show as int; otherwise
/// use up to 2 decimal places.
String formatTick(double v) {
  if (v == 0) return '0';
  if (v.abs() >= 1000) {
    // Show in thousands if large
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(0);
  }
  if (v % 1 == 0) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

(String, String) parseColor(String hex) {
  // Assume #AARRGGBB
  if (hex.startsWith('#') && hex.length == 9) {
    final a = int.parse(hex.substring(1, 3), radix: 16) / 255.0;
    final rgb = '#${hex.substring(3)}';
    return (rgb, a.toStringAsFixed(2));
  }
  return (hex, '1.0');
}
