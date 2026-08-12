import 'dart:math';

import 'package:benchmarkhor/src/plot/line/line_data.dart';
import 'package:benchmarkhor/src/plot/line/line_renderer.dart';
import 'package:benchmarkhor/src/plot/svg.dart';
import 'package:test/test.dart';

const plotBottom = marginTop + plotHeight;

/// The y coordinate of the x axis (the highlighted y=0 line), if drawn.
double? xAxisY(String svg) {
  final match = RegExp(
    r'<line x1="[\d.]+" y1="([\d.]+)" x2="[\d.]+" '
    r'y2="[\d.]+" stroke="#eee"',
  ).firstMatch(svg);
  return match == null ? null : double.parse(match.group(1)!);
}

void main() {
  group('LineData', () {
    test('compute preserves value order (not sorted)', () {
      final data = LineData.compute('a', [5, 1, 4, 2, 3]);
      expect(data.values, [5, 1, 4, 2, 3]);
      expect(data.label, 'a');
    });

    test('compute handles empty input without crashing', () {
      final data = LineData.compute('empty', []);
      expect(data.values, isEmpty);
    });
  });

  group('buildLineSvg', () {
    test('single input produces one polyline with correct point count', () {
      final line = LineData.compute('a', [1, 2, 3, 4, 5]);
      final svg = buildLineSvg([line]);

      expect(svg, startsWith('<?xml'));
      expect(RegExp('<polyline').allMatches(svg).length, 1);

      final match = RegExp(r'<polyline points="([^"]*)"').firstMatch(svg)!;
      final points = match.group(1)!.trim().split(' ');
      expect(points.length, 5);
    });

    test('two inputs of different lengths share axes and use two colors', () {
      final lineA = LineData.compute('a', [1, 2, 3]);
      final lineB = LineData.compute('b', [10, 20, 30, 40, 50]);
      final svg = buildLineSvg([lineA, lineB]);

      expect(RegExp('<polyline').allMatches(svg).length, 2);

      final strokeMatches = RegExp(
        r'<polyline[^>]*stroke="([^"]*)"',
      ).allMatches(svg).toList();
      expect(strokeMatches.length, 2);
      expect(strokeMatches[0].group(1), isNot(strokeMatches[1].group(1)));

      // Both labels should appear in the legend.
      expect(svg, contains('>a<'));
      expect(svg, contains('>b<'));
    });

    test('skips drawing an empty-file line but does not crash', () {
      final lineA = LineData.compute('a', [1, 2, 3]);
      final lineEmpty = LineData.compute('empty', []);
      final svg = buildLineSvg([lineA, lineEmpty]);

      expect(RegExp('<polyline').allMatches(svg).length, 1);
    });

    test('all-positive data puts the x axis at the very bottom', () {
      final svg = buildLineSvg([
        LineData.compute('a', [10, 20, 30]),
      ]);

      expect(xAxisY(svg), closeTo(plotBottom, 1e-9));
    });

    test('all-negative data puts the x axis at the very top', () {
      final svg = buildLineSvg([
        LineData.compute('a', [-10, -20, -30]),
      ]);

      expect(xAxisY(svg), closeTo(marginTop, 1e-9));
    });

    test('data straddling zero puts the x axis inside the plot', () {
      final svg = buildLineSvg([
        LineData.compute('a', [-10, 5, 20]),
      ]);

      final y0 = xAxisY(svg)!;
      expect(y0, greaterThan(marginTop));
      expect(y0, lessThan(plotBottom));
    });

    test('there is exactly one x axis line', () {
      final svg = buildLineSvg([
        LineData.compute('a', [-10, 5, 20]),
      ]);

      expect(RegExp('stroke="#eee"').allMatches(svg).length, 1);
    });

    test('negative values are drawn below the x axis, inside the plot', () {
      final svg = buildLineSvg([
        LineData.compute('a', [-10, 5, 20]),
      ]);

      final y0 = xAxisY(svg)!;
      final ys = RegExp(r'<polyline points="([^"]*)"')
          .firstMatch(svg)!
          .group(1)!
          .split(' ')
          .map((p) => double.parse(p.split(',')[1]))
          .toList();

      // Larger pixel y means lower on the canvas.
      expect(ys.first, greaterThan(y0));
      expect(ys.reduce(max), lessThan(plotBottom));
      expect(ys.reduce(min), greaterThan(marginTop));
    });
  });
}
