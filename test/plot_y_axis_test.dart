import 'package:benchmarkhor/src/plot/plot_unit.dart';
import 'package:benchmarkhor/src/plot/svg.dart';
import 'package:benchmarkhor/src/plot/y_axis.dart';
import 'package:test/test.dart';

const defaultLayout = PlotLayout();
final plotBottom = defaultLayout.plotBottom;
final marginTop = defaultLayout.marginTop;

void main() {
  group('YAxis', () {
    test('all-positive range sits flush on zero, padded only on top', () {
      final axis = YAxis.forRange(400, 500);

      expect(axis.min, 0);
      expect(axis.max, greaterThan(500));
      // The zero baseline is the very bottom of the plot area.
      expect(axis.toSvgY(0), plotBottom);
      // The largest value doesn't touch the top edge.
      expect(axis.toSvgY(500), greaterThan(marginTop));
    });

    test(
      'all-negative range sits flush on zero, padded only at the bottom',
      () {
        final axis = YAxis.forRange(-500, -400);

        expect(axis.max, 0);
        expect(axis.min, lessThan(-500));
        // The zero baseline is the very top of the plot area.
        expect(axis.toSvgY(0), marginTop);
        // The smallest value doesn't touch the bottom edge.
        expect(axis.toSvgY(-500), lessThan(plotBottom));
      },
    );

    test('range straddling zero is padded on both ends', () {
      final axis = YAxis.forRange(-100, 200);

      expect(axis.min, lessThan(-100));
      expect(axis.max, greaterThan(200));
      // Zero is somewhere strictly inside the plot area.
      final y0 = axis.toSvgY(0);
      expect(y0, greaterThan(marginTop));
      expect(y0, lessThan(plotBottom));
      // No point touches an edge.
      expect(axis.toSvgY(-100), lessThan(plotBottom));
      expect(axis.toSvgY(200), greaterThan(marginTop));
    });

    test('always contains zero, even when data is far from it', () {
      expect(YAxis.forRange(1000, 2000).containsZero, isTrue);
      expect(YAxis.forRange(-2000, -1000).containsZero, isTrue);
    });

    test('degenerate all-zero range produces finite coordinates', () {
      final axis = YAxis.forRange(0, 0);

      expect(axis.max, greaterThan(axis.min));
      expect(axis.toSvgY(0).isFinite, isTrue);
    });

    test('ticks span the axis and include zero', () {
      final axis = YAxis.forRange(-100, 200);

      expect(axis.ticks, contains(0.0));
      expect(axis.ticks.first, greaterThanOrEqualTo(axis.min));
      expect(axis.ticks.last, lessThanOrEqualTo(axis.max));
    });

    test('adapts to custom layout height and margins', () {
      const customLayout = PlotLayout(height: 1000);
      final axis = YAxis.forRange(400, 500, layout: customLayout);

      expect(axis.toSvgY(0), customLayout.plotBottom);
      expect(axis.toSvgY(500), greaterThan(customLayout.marginTop));
    });

    group('with PlotUnit.ratio', () {
      test('all-greater-than-1.0 range sits flush on 1.0 baseline', () {
        final axis = YAxis.forRange(1.02, 1.05, unit: PlotUnit.ratio);

        expect(axis.min, closeTo(1.0, 1e-9));
        expect(axis.max, greaterThan(1.05));
        expect(axis.toSvgY(1.0), closeTo(plotBottom, 1e-9));
        expect(axis.toSvgY(1.05), greaterThan(marginTop));
        expect(axis.containsBaseline, isTrue);
      });

      test('all-less-than-1.0 range sits flush on 1.0 baseline', () {
        final axis = YAxis.forRange(0.80, 0.95, unit: PlotUnit.ratio);

        expect(axis.max, closeTo(1.0, 1e-9));
        expect(axis.min, lessThan(0.80));
        expect(axis.toSvgY(1.0), closeTo(marginTop, 1e-9));
        expect(axis.toSvgY(0.80), lessThan(plotBottom));
        expect(axis.containsBaseline, isTrue);
      });

      test('range straddling 1.0 is padded on both ends', () {
        final axis = YAxis.forRange(0.95, 1.05, unit: PlotUnit.ratio);

        expect(axis.min, lessThan(0.95));
        expect(axis.max, greaterThan(1.05));
        final y1 = axis.toSvgY(1.0);
        expect(y1, greaterThan(marginTop));
        expect(y1, lessThan(plotBottom));
      });
    });
  });
}
