import 'dart:math';

import 'package:benchmarkhor/src/plot/svg.dart';
import 'package:benchmarkhor/src/plot/violin/violin_data.dart';
import 'package:benchmarkhor/src/plot/y_axis.dart';

// ---------------------------------------------------------------------------
// SVG rendering
// ---------------------------------------------------------------------------

String buildViolinSvg(List<ViolinData> violins) {
  // Plot range: the span of values the plot commits to showing. Values
  // outside of it are excluded (and summarised in a note instead).
  double plotMaximum = 0;
  double plotMinimum = 0;
  for (final v in violins) {
    if (v.sorted.isEmpty) continue;
    plotMaximum = max(plotMaximum, v.inputMax);
    plotMinimum = min(plotMinimum, v.inputMin);
  }

  final axis = YAxis.forRange(plotMinimum, plotMaximum);
  final ticks = axis.ticks;
  final axisMin = axis.min;
  final axisMax = axis.max;
  final toSvgY = axis.toSvgY;

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

  // --- y=0 axis line (highlighted) ---
  if (axisMin <= 0 && 0 <= axisMax) {
    final y0 = toSvgY(0);
    buf.writeln(
      '<line x1="$axisX" y1="$y0" x2="${axisX + plotWidth}" y2="$y0" '
      'stroke="#eee" stroke-width="1.5"/>',
    );
  }

  // --- Violins ---
  for (int i = 0; i < violins.length; i++) {
    final v = violins[i];
    if (v.sorted.isEmpty) continue;

    final slotCenterX = marginLeft + slotWidth * (i + 0.5);
    final colorHex = colors[i % colors.length];
    final (fillColor, fillOpacity) = parseColor(colorHex);
    final strokeColorHex = colorHex.replaceRange(0, 3, '#33');
    final (strokeColor, strokeOpacity) = parseColor(strokeColorHex);

    // Max half-width in pixels for this violin
    final maxHalfPx = slotWidth * maxHalfWidthFraction;

    // Convert KDE to SVG polygon points
    // Left side: (center - halfWidth, svgY)
    // Right side: (center + halfWidth, svgY)  — mirrored
    if (v.kdePoints.isNotEmpty) {
      final rightPoints = StringBuffer();
      final leftPoints = StringBuffer();
      for (final (y, density) in v.kdePoints) {
        if (y < plotMinimum || y > plotMaximum) continue;
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
      'font-size="14" font-weight="bold" fill="#eee">${v.label}</text>',
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
      'stroke="white" stroke-width="1.5"/>',
    );
    buf.writeln(
      '<line x1="$slotCenterX" y1="$yQ1" '
      'x2="$slotCenterX" y2="$yWhiskerLo" '
      'stroke="white" stroke-width="1.5"/>',
    );

    // Whisker caps (horizontal)
    buf.writeln(
      '<line x1="${slotCenterX - 8}" y1="$yWhiskerHi" '
      'x2="${slotCenterX + 8}" y2="$yWhiskerHi" '
      'stroke="white" stroke-width="1.5"/>',
    );
    buf.writeln(
      '<line x1="${slotCenterX - 8}" y1="$yWhiskerLo" '
      'x2="${slotCenterX + 8}" y2="$yWhiskerLo" '
      'stroke="white" stroke-width="1.5"/>',
    );

    // IQR box
    buf.writeln(
      '<rect x="${slotCenterX - boxHalfWidth}" y="$yQ3" '
      'width="${boxHalfWidth * 2}" height="${yQ1 - yQ3}" '
      'fill="none" stroke="white" stroke-width="2"/>',
    );

    // Median line
    buf.writeln(
      '<line x1="${slotCenterX - boxHalfWidth}" y1="$yMedian" '
      'x2="${slotCenterX + boxHalfWidth}" y2="$yMedian" '
      'stroke="white" stroke-width="2.5"/>',
    );

    // --- Outliers ---
    int excludedAboveCount = 0;
    double? excludedMax;
    int excludedBelowCount = 0;
    double? excludedMin;
    for (final o in v.outliers) {
      if (o > plotMaximum) {
        excludedAboveCount++;
        excludedMax = excludedMax == null ? o : max(excludedMax, o);
        continue;
      }
      if (o < plotMinimum) {
        excludedBelowCount++;
        excludedMin = excludedMin == null ? o : min(excludedMin, o);
        continue;
      }
      final oy = toSvgY(o);
      buf.writeln(
        '<circle cx="$slotCenterX" cy="$oy" r="3" '
        'stroke="white" opacity="0.7"/>',
      );
    }

    // --- Outlier notes ---
    if (excludedAboveCount > 0) {
      final formattedMax = formatTick(excludedMax!);
      final note = '+$excludedAboveCount outliers (max $formattedMax)';
      buf.writeln(
        '<text x="$slotCenterX" y="${marginTop - 10}" '
        'text-anchor="middle" font-family="Arial,sans-serif" '
        'font-size="11" fill="#aaa">$note</text>',
      );
    }
    if (excludedBelowCount > 0) {
      final formattedMin = formatTick(excludedMin!);
      final note = '+$excludedBelowCount outliers (min $formattedMin)';
      buf.writeln(
        '<text x="$slotCenterX" y="${marginTop + plotHeight + 12}" '
        'text-anchor="middle" font-family="Arial,sans-serif" '
        'font-size="11" fill="#aaa">$note</text>',
      );
    }
  }

  buf.writeln('</svg>');
  return buf.toString();
}
