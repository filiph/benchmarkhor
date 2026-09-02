import 'package:benchmarkhor/src/plot/labels.dart';
import 'package:test/test.dart';

void main() {
  group('computeLabels', () {
    test('returns empty list for empty input', () {
      expect(computeLabels([]), isEmpty);
    });

    test('preserves label for a single file', () {
      expect(computeLabels(['foo_bar.dat']), ['foo_bar']);
    });

    test('removes single common prefix segment', () {
      expect(
        computeLabels(['foo_bar.dat', 'foo_baz.dat']),
        ['bar', 'baz'],
      );
    });

    test('removes multi-segment common prefix', () {
      expect(
        computeLabels([
          'build_mean_foo.dat',
          'build_mean_bar.dat',
          'build_mean_baz.dat',
        ]),
        ['foo', 'bar', 'baz'],
      );
    });

    test('leaves labels untouched when no prefix is shared', () {
      expect(
        computeLabels(['foo_bar.dat', 'qux_baz.dat']),
        ['foo_bar', 'qux_baz'],
      );
    });

    test('respects removeCommonPrefix: false', () {
      expect(
        computeLabels(
          ['foo_bar.dat', 'foo_baz.dat'],
          removeCommonPrefix: false,
        ),
        ['foo_bar', 'foo_baz'],
      );
    });

    test('preserves original names when stripping would leave an empty label', () {
      expect(
        computeLabels(['foo.dat', 'foo_bar.dat']),
        ['foo', 'foo_bar'],
      );
    });

    test('preserves original names for identical files', () {
      expect(
        computeLabels(['foo_bar.dat', 'foo_bar.dat']),
        ['foo_bar', 'foo_bar'],
      );
    });

    test('handles paths with directory prefixes and case-insensitive extensions', () {
      expect(
        computeLabels([
          '/tmp/data/suite_alpha.DAT',
          'relative/dir/suite_beta.dat',
        ]),
        ['alpha', 'beta'],
      );
    });
  });
}
