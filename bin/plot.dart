import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:t_stats/t_stats.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Parse a .dat file: one number per line; non-number lines are ignored.
List<num> parseDat(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('File not found: $path');
    exit(1);
  }
  final values = <num>[];
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    final parsed = num.tryParse(trimmed);
    if (parsed != null) values.add(parsed);
  }
  return values;
}

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
  });

  factory ViolinData.compute(String label, List<num> values) {
    if (values.isEmpty) {
      stderr.writeln('Warning: $label has no data.');
    }
    final sorted = List<num>.from(values)..sort((a, b) => a.compareTo(b));
    final stat = Statistic.from(sorted.map((v) => v.toDouble()).toList());

    final q1 = percentile(sorted, 0.25);
    final med = percentile(sorted, 0.50);
    final q3 = percentile(sorted, 0.75);
    final iqr = q3 - q1;

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

    // KDE over the full data range (whisker range + 3 bandwidths)
    final stdDev = stat.stdDeviation.toDouble();
    double bw = 1.06 * stdDev * pow(sorted.length, -0.2);
    if (bw == 0) bw = 1.0;
    final kdeMin = sorted.first.toDouble() - 3 * bw;
    final kdeMax = sorted.last.toDouble() + 3 * bw;
    final kdePoints = kde(sorted, kdeMin, kdeMax, bwOverride: bw);
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
    );
  }
}

// ---------------------------------------------------------------------------
// SVG rendering
// ---------------------------------------------------------------------------

String buildSvg(List<ViolinData> violins) {
  // Global y range: 0 to max of all data (including outliers and KDE tails)
  double globalYMax = 0;
  double globalYMin = double.infinity;
  for (final v in violins) {
    if (v.sorted.isEmpty) continue;
    for (final p in v.kdePoints) {
      globalYMax = max(globalYMax, p.$1);
      globalYMin = min(globalYMin, p.$1);
    }
    // Also consider raw data for safety (though KDE usually spans it)
    globalYMax = max(globalYMax, v.sorted.last.toDouble());
    globalYMin = min(globalYMin, v.sorted.first.toDouble());
  }
  // Always include 0
  globalYMin = min(globalYMin, 0);
  // Add 5% padding on top
  final yRange = globalYMax - globalYMin;
  final yAxisMax = globalYMax + yRange * 0.05;
  final yAxisMin = globalYMin;

  // Ticks
  final ticks = niceTicks(yAxisMin, yAxisMax, targetCount: 7);
  // Extend axis to encompass last tick
  final axisMax = max(yAxisMax, ticks.last);
  final axisMin = min(yAxisMin, ticks.first);

  // Map a data-y value to SVG pixel y (inverted: larger y → smaller pixel y)
  double toSvgY(double y) {
    return marginTop + plotHeight * (1 - (y - axisMin) / (axisMax - axisMin));
  }

  // Horizontal spacing for violins
  final count = violins.length;
  final slotWidth = plotWidth / count;

  // Global max density across all violins (for normalised width)
  double globalMaxDensity = 0.0;
  for (final v in violins) {
    if (v.maxDensity > globalMaxDensity) globalMaxDensity = v.maxDensity;
  }
  if (globalMaxDensity == 0) globalMaxDensity = 1.0;

  // Max half-width a violin can take (as fraction of slot width)
  const maxHalfWidthFraction = 0.42;

  final buf = SvgBuffer();

  buf.writeln(
    '<?xml version="1.0" encoding="utf-8"?>',
  );
  buf.writeln(
    '<svg xmlns="http://www.w3.org/2000/svg" '
    'width="$svgWidth" height="$svgHeight" '
    'viewBox="0 0 $svgWidth $svgHeight">',
  );

  // Background
  buf.writeln(
    '<rect width="$svgWidth" height="$svgHeight" fill="white"/>',
  );

  // --- Y axis line ---
  final axisX = marginLeft;
  buf.writeln(
    '<line x1="$axisX" y1="$marginTop" x2="$axisX" '
    'y2="${marginTop + plotHeight}" stroke="#444" stroke-width="1.5"/>',
  );

  // --- Tick marks and labels ---
  for (final tick in ticks) {
    if (tick < axisMin - 1e-9 || tick > axisMax + 1e-9) continue;
    final ty = toSvgY(tick);
    // Tick mark
    buf.writeln(
      '<line x1="${axisX - 6}" y1="$ty" x2="$axisX" y2="$ty" '
      'stroke="#444" stroke-width="1.2"/>',
    );
    // Light grid line
    buf.writeln(
      '<line x1="$axisX" y1="$ty" x2="${axisX + plotWidth}" y2="$ty" '
      'stroke="#e0e0e0" stroke-width="0.8"/>',
    );
    // Label
    final label = _formatTick(tick);
    buf.writeln(
      '<text x="${axisX - 10}" y="${ty + 4}" '
      'text-anchor="end" font-family="Arial,sans-serif" '
      'font-size="12" fill="#444">$label</text>',
    );
  }

  // --- y=0 axis line (highlighted) ---
  if (axisMin <= 0 && 0 <= axisMax) {
    final y0 = toSvgY(0);
    buf.writeln(
      '<line x1="$axisX" y1="$y0" x2="${axisX + plotWidth}" y2="$y0" '
      'stroke="#222" stroke-width="1.5"/>',
    );
  }

  // --- Violins ---
  final colors = [
    '#8033bbbb', // teal
    '#80bbaa44', // yellow-green
    '#8066aaee', // blue
    '#80ee8844', // orange
    '#80bb44aa', // pink
    '#8044bb66', // green
    '#80eeaa44', // amber
    '#80aa44ee', // purple
  ];

  for (int i = 0; i < violins.length; i++) {
    final v = violins[i];
    if (v.sorted.isEmpty) continue;

    final slotCenterX = marginLeft + slotWidth * (i + 0.5);
    final colorHex = colors[i % colors.length];
    final (fillColor, fillOpacity) = _parseColor(colorHex);
    final strokeColorHex = colorHex.replaceRange(0, 3, '#33');
    final (strokeColor, strokeOpacity) = _parseColor(strokeColorHex);

    // Max half-width in pixels for this violin
    final maxHalfPx = slotWidth * maxHalfWidthFraction;

    // Convert KDE to SVG polygon points
    // Left side: (center - halfWidth, svgY)
    // Right side: (center + halfWidth, svgY)  — mirrored
    if (v.kdePoints.isNotEmpty) {
      final rightPoints = StringBuffer();
      final leftPoints = StringBuffer();
      for (final (y, density) in v.kdePoints) {
        final svgY = toSvgY(y);
        final halfW = (density / globalMaxDensity) * maxHalfPx;
        rightPoints.write('${slotCenterX + halfW},$svgY ');
        leftPoints.write('${slotCenterX - halfW},$svgY ');
      }

      // Polygon: right side top→bottom, then left side bottom→top
      final rightList = rightPoints.toString().trim().split(' ');
      final leftList = leftPoints.toString().trim().split(' ');
      final leftReversed = leftList.reversed.toList();
      final polyPoints =
          [...rightList, ...leftReversed].where((s) => s.isNotEmpty).join(' ');

      buf.writeln(
        '<polygon points="$polyPoints" fill="$fillColor" fill-opacity="$fillOpacity" '
        'stroke="$strokeColor" stroke-opacity="$strokeOpacity" stroke-width="0.5"/>',
      );
    }

    // --- Label ---
    buf.writeln(
      '<text x="$slotCenterX" y="${marginTop + plotHeight + 25}" '
      'text-anchor="middle" font-family="Arial,sans-serif" '
      'font-size="14" font-weight="bold" fill="#444">${v.label}</text>',
    );

    // --- Box plot ---
    // Box dimensions
    const boxHalfWidth = 18.0;

    final yQ1 = toSvgY(v.q1);
    final yQ3 = toSvgY(v.q3);
    final yMedian = toSvgY(v.median);
    final yWhiskerLo = toSvgY(v.whiskerLo);
    final yWhiskerHi = toSvgY(v.whiskerHi);

    // Whisker lines (vertical centre line)
    buf.writeln(
      '<line x1="$slotCenterX" y1="$yWhiskerHi" '
      'x2="$slotCenterX" y2="$yQ3" '
      'stroke="black" stroke-width="1.5"/>',
    );
    buf.writeln(
      '<line x1="$slotCenterX" y1="$yQ1" '
      'x2="$slotCenterX" y2="$yWhiskerLo" '
      'stroke="black" stroke-width="1.5"/>',
    );

    // Whisker caps (horizontal)
    buf.writeln(
      '<line x1="${slotCenterX - 8}" y1="$yWhiskerHi" '
      'x2="${slotCenterX + 8}" y2="$yWhiskerHi" '
      'stroke="black" stroke-width="1.5"/>',
    );
    buf.writeln(
      '<line x1="${slotCenterX - 8}" y1="$yWhiskerLo" '
      'x2="${slotCenterX + 8}" y2="$yWhiskerLo" '
      'stroke="black" stroke-width="1.5"/>',
    );

    // IQR box
    buf.writeln(
      '<rect x="${slotCenterX - boxHalfWidth}" y="$yQ3" '
      'width="${boxHalfWidth * 2}" height="${yQ1 - yQ3}" '
      'fill="white" stroke="black" stroke-width="2"/>',
    );

    // Median line
    buf.writeln(
      '<line x1="${slotCenterX - boxHalfWidth}" y1="$yMedian" '
      'x2="${slotCenterX + boxHalfWidth}" y2="$yMedian" '
      'stroke="black" stroke-width="2.5"/>',
    );

    // --- Outliers ---
    for (final o in v.outliers) {
      final oy = toSvgY(o);
      buf.writeln(
        '<circle cx="$slotCenterX" cy="$oy" r="3" '
        'fill="black" opacity="0.7"/>',
      );
    }
  }

  buf.writeln('</svg>');
  return buf.toString();
}

/// Format a tick value: if it's a whole number, show as int; otherwise
/// use up to 2 decimal places.
String _formatTick(double v) {
  if (v == 0) return '0';
  if (v.abs() >= 1000) {
    // Show in thousands if large
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(0);
  }
  if (v % 1 == 0) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

(String, String) _parseColor(String hex) {
  // Assume #AARRGGBB
  if (hex.startsWith('#') && hex.length == 9) {
    final a = int.parse(hex.substring(1, 3), radix: 16) / 255.0;
    final rgb = '#${hex.substring(3)}';
    return (rgb, a.toStringAsFixed(2));
  }
  return (hex, '1.0');
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addMultiOption(
      'input',
      abbr: 'i',
      help: 'Input .dat file (can be specified multiple times).',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help.',
    );

  late ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    stderr.writeln('Error: $e');
    stderr.writeln(parser.usage);
    exit(1);
  }

  if (args['help'] as bool) {
    stderr.writeln(
        'Usage: dart run violin_plot.dart -i file1.dat [-i file2.dat ...]');
    stderr.writeln(parser.usage);
    exit(0);
  }

  final inputs = args['input'] as List<String>;
  if (inputs.isEmpty) {
    stderr.writeln('Error: at least one --input (-i) file is required.');
    stderr.writeln(parser.usage);
    exit(1);
  }

  final violins = <ViolinData>[];
  for (final path in inputs) {
    final values = parseDat(path);
    // Use the filename (without extension) as the label
    final label = path.split(Platform.pathSeparator).last.replaceAll(
          RegExp(r'\.dat$', caseSensitive: false),
          '',
        );
    violins.add(ViolinData.compute(label, values));
  }

  final svg = buildSvg(violins);
  stdout.write(svg);
}
