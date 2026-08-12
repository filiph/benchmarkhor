import 'dart:math';

import 'package:benchmarkhor/bootstrap_sample_size.dart';
import 'package:test/test.dart';

void main() {
  group('calculateBootstrapSampleSize', () {
    test('computes reasonable sample size for pilot data', () {
      final pilotBase = [46.2, 51.8, 44.0, 49.5, 45.1, 47.7, 44.3, 52.0, 46.9, 48.2];
      final pilotA = [44.1, 48.9, 43.7, 46.0, 44.2, 45.1, 43.0, 49.4, 45.0, 46.1];
      final diffs = List<double>.generate(
        pilotBase.length,
        (i) => pilotA[i] - pilotBase[i],
      );
      final baseMean = pilotBase.reduce((a, b) => a + b) / pilotBase.length;

      // With SESOI = 0.05 (5% change of baseMean ≈ 2.378 ms), sample size should be calculated.
      final sampleSize = calculateBootstrapSampleSize(
        diffs: diffs,
        baseMean: baseMean,
        sesoi: 0.05,
        alpha: 0.05,
        power: 0.80,
        nSims: 1000,
        random: Random(42),
      );

      expect(sampleSize, greaterThan(2));
      expect(sampleSize, lessThan(500));
    });

    test('returns 0 if diffs is empty or sesoi is 0', () {
      expect(
        calculateBootstrapSampleSize(
          diffs: [],
          baseMean: 100.0,
          sesoi: 0.05,
        ),
        equals(0),
      );

      expect(
        calculateBootstrapSampleSize(
          diffs: [-1.0, 1.0, -0.5, 0.5],
          baseMean: 100.0,
          sesoi: 0.0,
        ),
        equals(0),
      );
    });

    test('larger effect size requires smaller sample size', () {
      final diffs = [-2.0, 1.5, -1.0, 0.5, -2.5, 1.0, -1.5, 0.0];
      const baseMean = 100.0;

      final nSmallEffect = calculateBootstrapSampleSize(
        diffs: diffs,
        baseMean: baseMean,
        sesoi: 0.02,
        random: Random(123),
      );

      final nLargeEffect = calculateBootstrapSampleSize(
        diffs: diffs,
        baseMean: baseMean,
        sesoi: 0.10,
        random: Random(123),
      );

      expect(nLargeEffect, lessThanOrEqualTo(nSmallEffect));
    });
  });
}
