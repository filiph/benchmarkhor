import 'package:test/test.dart';

import '../bin/extract_dat.dart' show percentile, superquantile;

void main() {
  group('p95 superquantile', () {
    test('averages a whole tail when 5% is a whole number of frames', () {
      // 40 frames: the worst 5% are exactly the worst two.
      final frames = [for (var i = 1; i <= 38; i++) i, 100, 200];
      expect(superquantile(frames, 0.95), closeTo(150, 0.0001));
    });

    test('weights the boundary frame by the leftover of the tail', () {
      // 30 frames: the tail is 1.5 frames, so the worst counts in full and
      // the second worst counts for half. (200 + 0.5 * 100) / 1.5
      final frames = [for (var i = 1; i <= 28; i++) i, 100, 200];
      expect(superquantile(frames, 0.95), closeTo(166.6667, 0.0001));
    });

    test('is the worst frame when the tail is thinner than one frame', () {
      final frames = [for (var i = 1; i <= 20; i++) i * 10];
      expect(superquantile(frames, 0.95), closeTo(200, 0.0001));

      final short = [for (var i = 1; i <= 12; i++) i * 10];
      expect(superquantile(short, 0.95), closeTo(120, 0.0001));
    });

    test('is the only frame of a single-frame phase', () {
      expect(superquantile([42], 0.95), closeTo(42, 0.0001));
    });

    test('is never below the p95 it complements', () {
      final frames = [for (var i = 1; i <= 703; i++) i * i];
      expect(
        superquantile(frames, 0.95),
        greaterThan(percentile(frames, 0.95)),
      );
    });

    test('reacts to how bad the worst frames are, unlike p95', () {
      final mild = [for (var i = 1; i <= 99; i++) 10, 100];
      final severe = [for (var i = 1; i <= 99; i++) 10, 10000];
      expect(percentile(mild, 0.95), equals(percentile(severe, 0.95)));
      expect(
        superquantile(severe, 0.95),
        greaterThan(superquantile(mild, 0.95)),
      );
    });

    test('is zero for no frames', () {
      expect(superquantile([], 0.95), equals(0));
    });
  });
}
