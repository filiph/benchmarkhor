import 'dart:math';

import 'package:benchmarkhor/src/plot/dat_parser.dart';
import 'package:benchmarkhor/src/plot/svg.dart';
import 'package:benchmarkhor/src/plot/violin/violin_data.dart';
import 'package:benchmarkhor/src/plot/violin/violin_renderer.dart';
import 'package:test/test.dart';

const plotBottom = marginTop + plotHeight;

/// The y coordinate of the highlighted y=0 line, if drawn.
double? zeroLineY(String svg) {
  final match = RegExp(r'<line x1="[\d.]+" y1="([\d.]+)" x2="[\d.]+" '
          r'y2="[\d.]+" stroke="#eee"')
      .firstMatch(svg);
  return match == null ? null : double.parse(match.group(1)!);
}

/// The y coordinates of all outlier circles.
List<double> outlierYs(String svg) =>
    RegExp(r'<circle cx="[-\d.]+" cy="([-\d.]+)"')
        .allMatches(svg)
        .map((m) => double.parse(m.group(1)!))
        .toList();

void main() {
  group('buildViolinSvg', () {
    test('output starts with valid SVG header', () {
      final values = parseDat('test/fixtures/sample_a.dat');
      final violin = ViolinData.compute('sample_a', values);
      final svg = buildViolinSvg([violin]);

      expect(svg, startsWith('<?xml'));
      expect(svg, contains('<svg'));
    });

    test('renders the sample fixtures on shared axes', () {
      final violins = [
        'test/fixtures/sample_a.dat',
        'test/fixtures/sample_b.dat'
      ].map((path) => ViolinData.compute(path, parseDat(path))).toList();

      final svg = buildViolinSvg(violins);

      // Each violin renders 1 polygon for KDE shape + 1 polygon for notched box
      expect(RegExp('<polygon').allMatches(svg).length, 4);
      expect(svg, endsWith('</svg>\n'));
    });

    test('all-positive data puts the zero line at the very bottom', () {
      final violin =
          ViolinData.compute('a', [100, 110, 120, 130, 140, 150, 160]);
      final svg = buildViolinSvg([violin]);

      expect(zeroLineY(svg), closeTo(plotBottom, 1e-9));
    });

    test('all-negative data puts the zero line at the very top', () {
      final violin =
          ViolinData.compute('a', [-100, -110, -120, -130, -140, -150, -160]);
      final svg = buildViolinSvg([violin]);

      expect(zeroLineY(svg), closeTo(marginTop, 1e-9));
    });

    test('data straddling zero puts the zero line inside the plot', () {
      final violin =
          ViolinData.compute('a', [-30, -20, -10, 0, 10, 20, 30, 40, 50]);
      final svg = buildViolinSvg([violin]);

      final y0 = zeroLineY(svg)!;
      expect(y0, greaterThan(marginTop));
      expect(y0, lessThan(plotBottom));
    });

    test('negative data is drawn below the zero line', () {
      final violin =
          ViolinData.compute('a', [-30, -20, -10, 0, 10, 20, 30, 40, 50]);
      final svg = buildViolinSvg([violin]);

      final y0 = zeroLineY(svg)!;
      final polygonYs = RegExp(r'<polygon points="([^"]*)"')
          .firstMatch(svg)!
          .group(1)!
          .trim()
          .split(' ')
          .map((p) => double.parse(p.split(',')[1]));

      // Larger pixel y means lower on the canvas.
      expect(polygonYs.reduce(max), greaterThan(y0));
    });

    test('renders notched box plot polygon and median line across waist', () {
      final violin =
          ViolinData.compute('a', [100, 110, 120, 130, 140, 150, 160]);
      final svg = buildViolinSvg([violin]);

      // Box plot rendered as a polygon with points
      expect(svg, contains('<polygon points="'));
      // Median line rendered across notch waist (width 21.6 = 2 * 10.8)
      expect(svg, contains('stroke-width="2.5"'));
    });

    test('outliers far below the plot minimum are summarised, not drawn', () {
      // A tight distribution plus one extreme low value.
      final values = <num>[
        for (var i = 0; i < 40; i++) 100 + i % 5,
        -100000,
      ];
      final violin = ViolinData.compute('a', values);
      final svg = buildViolinSvg([violin]);

      expect(svg, contains('outliers (min -100000)'));
      // Nothing is drawn outside the plot area.
      for (final y in outlierYs(svg)) {
        expect(y, lessThanOrEqualTo(plotBottom + 1e-9));
        expect(y, greaterThanOrEqualTo(marginTop - 1e-9));
      }
    });

    test('outliers far above the plot maximum are still summarised', () {
      final values = <num>[
        for (var i = 0; i < 40; i++) 100 + i % 5,
        100000,
      ];
      final violin = ViolinData.compute('a', values);
      final svg = buildViolinSvg([violin]);

      expect(svg, contains('outliers (max 100000)'));
    });
  });

  group('ViolinData', () {
    test('computes notch bounds using McGill formula', () {
      final values = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
      final data = ViolinData.compute('a', values);

      // IQR = Q3 (77.5) - Q1 (32.5) = 45.0
      // med = 55.0
      // notchDelta = 1.58 * 45.0 / sqrt(10) = 71.1 / 3.16227766... = 22.4837...
      expect(data.iqr, closeTo(45.0, 1e-9));
      expect(data.median, closeTo(55.0, 1e-9));
      final expectedDelta = 1.58 * 45.0 / sqrt(10);
      expect(data.notchLo, closeTo(55.0 - expectedDelta, 1e-9));
      expect(data.notchHi, closeTo(55.0 + expectedDelta, 1e-9));
    });

    test('input range is symmetric around median when straddling zero', () {
      final data = ViolinData.compute('a', [-20, -10, 0, 10, 20]);

      expect(data.inputMax - data.median,
          closeTo(data.median - data.inputMin, 1e-9));
    });

    test('input range is bounded at zero for all-positive data', () {
      final data = ViolinData.compute('a', [10, 20, 30, 40, 50]);

      expect(data.inputMin, 0.0);
    });

    test('all-positive data with large IQR keeps zero line at plot bottom', () {
      // Median ~2200, IQR ~1500 -> med - 3*iqr would be negative (-2300)
      final data = ViolinData.compute('a', [200, 500, 2200, 3700, 5000]);
      expect(data.inputMin, 0.0);

      final svg = buildViolinSvg([data]);
      expect(zeroLineY(svg), closeTo(plotBottom, 1e-9));
      expect(svg, isNot(contains('-1000')));
    });
  });
}
