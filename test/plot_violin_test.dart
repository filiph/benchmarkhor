import 'dart:io';

import 'package:benchmarkhor/src/plot/dat_parser.dart';
import 'package:benchmarkhor/src/plot/violin/violin_data.dart';
import 'package:benchmarkhor/src/plot/violin/violin_renderer.dart';
import 'package:test/test.dart';

void main() {
  group('buildViolinSvg', () {
    test('output is unchanged from pre-refactor behavior (regression)', () {
      final paths = [
        'test/fixtures/sample_a.dat',
        'test/fixtures/sample_b.dat',
      ];
      final violins = paths.map((path) {
        final values = parseDat(path);
        final label =
            path.split(Platform.pathSeparator).last.replaceAll('.dat', '');
        return ViolinData.compute(label, values);
      }).toList();

      final svg = buildViolinSvg(violins);
      final golden = File('test/fixtures/violin_golden.svg').readAsStringSync();

      expect(svg, golden);
    });

    test('output starts with valid SVG header', () {
      final values = parseDat('test/fixtures/sample_a.dat');
      final violin = ViolinData.compute('sample_a', values);
      final svg = buildViolinSvg([violin]);

      expect(svg, startsWith('<?xml'));
      expect(svg, contains('<svg'));
    });
  });
}
