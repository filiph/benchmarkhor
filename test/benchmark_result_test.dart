import 'package:benchmarkhor/benchmark_result.dart';
import 'package:test/test.dart';

void main() {
  group('BenchmarkResult', () {
    test('saves and loads well-formed and everything', () {
      final series = MeasurementSeries(
          'UI thread', List.generate(100, (index) => index * index));
      final timestamp = DateTime.utc(2022, 1, 3, 6, 55);
      final result = BenchmarkResult(
        label: 'こんにちは世界',
        timestamp: timestamp,
        series: [series],
      );
      final bytes = result.toBytes();
      final recovered = BenchmarkResult.fromBytes(bytes);
      expect(recovered.label, 'こんにちは世界');
      expect(recovered.timestamp, timestamp);
      expect(recovered.series.length, 1);
      expect(recovered.series.single.measurements.length,
          series.measurements.length);
      expect(recovered.series.single.measurements.first,
          series.measurements.first);
      expect(recovered.series.single.measurements[1], series.measurements[1]);
      expect(
          recovered.series.single.measurements.last, series.measurements.last);
    });
  });

  group('MeasurementSeries', () {
    test('saves and loads well-formed', () {
      final series = MeasurementSeries(
          'こんにちは世界', List.generate(100, (index) => index * index));
      final bytes = series.toBytes();
      final recovered = MeasurementSeries.fromBytes(bytes);
      expect(recovered.label, 'こんにちは世界');
      expect(recovered.measurements.length, series.measurements.length);
      expect(recovered.measurements.first, series.measurements.first);
      expect(recovered.measurements[1], series.measurements[1]);
      expect(recovered.measurements.last, series.measurements.last);
    });

    test('saves and loads different lengths of label', () {
      for (var length = 0; length < 10; length++) {
        var label = '';
        for (var i = 0; i < length; i++) {
          label += '*';
        }
        final series =
            MeasurementSeries(label, List.generate(10, (index) => 0));
        final bytes = series.toBytes();
        final recovered = MeasurementSeries.fromBytes(bytes);
        expect(recovered.label, series.label);
      }
    });
  });
}
