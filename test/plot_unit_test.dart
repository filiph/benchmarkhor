import 'package:benchmarkhor/src/plot/plot_unit.dart';
import 'package:test/test.dart';

void main() {
  group('PlotUnit', () {
    test('fromString parses supported units', () {
      expect(PlotUnit.fromString('microseconds'), PlotUnit.microseconds);
      expect(PlotUnit.fromString('ratio'), PlotUnit.ratio);
    });

    test('fromString throws on unsupported unit', () {
      expect(() => PlotUnit.fromString('invalid'), throwsArgumentError);
      expect(() => PlotUnit.fromString('ms'), throwsArgumentError);
    });

    group('microseconds formatting', () {
      test('formats zero and raw numbers without percentages', () {
        expect(PlotUnit.microseconds.formatValue(0), '0');
        expect(PlotUnit.microseconds.formatValue(500), '500');
        expect(PlotUnit.microseconds.formatValue(1500.25), '1500');
      });
    });

    group('ratio formatting', () {
      test('formats 1.0 as 0.0%', () {
        expect(PlotUnit.ratio.formatValue(1.0), '0.0%');
        expect(PlotUnit.ratio.formatValue(1.000), '0.0%');
      });

      test('formats 1.01 as +1.0%', () {
        expect(PlotUnit.ratio.formatValue(1.01), '+1.0%');
      });

      test('formats 0.5 as -50.0%', () {
        expect(PlotUnit.ratio.formatValue(0.5), '-50.0%');
      });

      test('formats small positive and negative changes', () {
        expect(PlotUnit.ratio.formatValue(1.05), '+5.0%');
        expect(PlotUnit.ratio.formatValue(0.95), '-5.0%');
        expect(PlotUnit.ratio.formatValue(1.234), '+23.4%');
      });

      test('avoids negative zero for near-baseline values', () {
        expect(PlotUnit.ratio.formatValue(0.9999), '0.0%');
        expect(PlotUnit.ratio.formatValue(1.0001), '0.0%');
      });
    });
  });
}
