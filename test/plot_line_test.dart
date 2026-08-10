import 'package:benchmarkhor/src/plot/line/line_data.dart';
import 'package:benchmarkhor/src/plot/line/line_renderer.dart';
import 'package:test/test.dart';

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

    test('two inputs of different lengths share axes and use two colors',
        () {
      final lineA = LineData.compute('a', [1, 2, 3]);
      final lineB = LineData.compute('b', [10, 20, 30, 40, 50]);
      final svg = buildLineSvg([lineA, lineB]);

      expect(RegExp('<polyline').allMatches(svg).length, 2);

      final strokeMatches =
          RegExp(r'<polyline[^>]*stroke="([^"]*)"').allMatches(svg).toList();
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
  });
}
