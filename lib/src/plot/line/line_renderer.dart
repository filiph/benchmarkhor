import 'dart:math';

import 'package:benchmarkhor/src/plot/line/line_data.dart';
import 'package:benchmarkhor/src/plot/svg.dart';
import 'package:benchmarkhor/src/plot/y_axis.dart';

// ---------------------------------------------------------------------------
// SVG rendering
// ---------------------------------------------------------------------------

String buildLineSvg(List<LineData> lines) {
  final nonEmptyLines = lines.where((l) => l.values.isNotEmpty).toList();

  // X range: point index, from 0 to the longest input's last index.
  int maxIndex = 0;
  for (final l in nonEmptyLines) {
    maxIndex = max(maxIndex, l.values.length - 1);
  }

  // Y range: min/max across all values. Unlike the violin plot, a line plot
  // never discards data, so nothing is clipped here; zero anchoring and axis
  // padding are handled by [YAxis].
  double globalYMin = double.infinity;
  double globalYMax = double.negativeInfinity;
  for (final l in nonEmptyLines) {
    for (final v in l.values) {
      final d = v.toDouble();
      globalYMin = min(globalYMin, d);
      globalYMax = max(globalYMax, d);
    }
  }
  if (nonEmptyLines.isEmpty) {
    globalYMin = 0;
    globalYMax = 0;
  }

  final axis = YAxis.forRange(globalYMin, globalYMax);
  final ticks = axis.ticks;
  final axisMin = axis.min;
  final axisMax = axis.max;
  final toSvgY = axis.toSvgY;

  // Map a point index to SVG pixel x.
  double toSvgX(int index) {
    if (maxIndex == 0) return marginLeft;
    return marginLeft + plotWidth * (index / maxIndex);
  }

  final buf = SvgBuffer();

  buf.writeln(
    '<?xml version="1.0" encoding="utf-8"?>',
  );
  buf.writeln(
    '<svg xmlns="http://www.w3.org/2000/svg" '
    'width="$svgWidth" height="$svgHeight" '
    'viewBox="0 0 $svgWidth $svgHeight">',
  );

  // --- Y axis line ---
  final axisX = marginLeft;
  buf.writeln(
    '<line x1="$axisX" y1="$marginTop" x2="$axisX" '
    'y2="${marginTop + plotHeight}" stroke="#ccc" stroke-width="1.5"/>',
  );

  // --- Tick marks and labels ---
  for (final tick in ticks) {
    if (tick < axisMin - 1e-9 || tick > axisMax + 1e-9) continue;
    final ty = toSvgY(tick);
    // Tick mark
    buf.writeln(
      '<line x1="${axisX - 6}" y1="$ty" x2="$axisX" y2="$ty" '
      'stroke="#ccc" stroke-width="1.2"/>',
    );
    // Light grid line
    buf.writeln(
      '<line x1="$axisX" y1="$ty" x2="${axisX + plotWidth}" y2="$ty" '
      'stroke="#333" stroke-width="0.8"/>',
    );
    // Label
    final label = formatTick(tick);
    buf.writeln(
      '<text x="${axisX - 10}" y="${ty + 4}" '
      'text-anchor="end" font-family="Arial,sans-serif" '
      'font-size="12" fill="#ccc">$label</text>',
    );
  }

  // --- X axis line (at y=0, not necessarily at the bottom of the plot) ---
  if (axis.containsZero) {
    final y0 = toSvgY(0);
    buf.writeln(
      '<line x1="$axisX" y1="$y0" x2="${axisX + plotWidth}" y2="$y0" '
      'stroke="#eee" stroke-width="1.5"/>',
    );
  }

  // --- Lines ---
  for (int i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.values.isEmpty) continue;

    final colorHex = colors[i % colors.length];
    final (strokeColor, strokeOpacity) =
        parseColor(colorHex.replaceRange(0, 3, '#ff'));

    final points = StringBuffer();
    for (int idx = 0; idx < l.values.length; idx++) {
      final x = toSvgX(idx);
      final y = toSvgY(l.values[idx].toDouble());
      points.write('$x,$y ');
    }

    buf.writeln(
      '<polyline points="${points.toString().trim()}" fill="none" '
      'stroke="$strokeColor" stroke-opacity="$strokeOpacity" '
      'stroke-width="2"/>',
    );
  }

  // --- Legend ---
  const legendLineHeight = 20.0;
  for (int i = 0; i < lines.length; i++) {
    final l = lines[i];
    final colorHex = colors[i % colors.length];
    final (strokeColor, strokeOpacity) =
        parseColor(colorHex.replaceRange(0, 3, '#ff'));
    final legendY = marginTop + i * legendLineHeight;
    final legendX = axisX + plotWidth - 150;

    buf.writeln(
      '<line x1="$legendX" y1="$legendY" x2="${legendX + 20}" y2="$legendY" '
      'stroke="$strokeColor" stroke-opacity="$strokeOpacity" stroke-width="2"/>',
    );
    buf.writeln(
      '<text x="${legendX + 26}" y="${legendY + 4}" '
      'font-family="Arial,sans-serif" font-size="12" fill="#eee">'
      '${l.label}</text>',
    );
  }

  buf.writeln('</svg>');
  return buf.toString();
}
