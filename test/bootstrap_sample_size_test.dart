import 'dart:math';

import 'package:benchmarkhor/bootstrap_sample_size.dart';
import 'package:test/test.dart';

void main() {
  // ------------------------------------------------------------------
  // The correctness test: does the simulation agree with the textbook?
  //
  // On Gaussian noise the answer is known analytically, so this is the
  // only test in the file that can catch a *systematic* error - a missing
  // Bessel correction, an off-by-one in df, a one- vs two-tailed mixup.
  // Every other test here only checks internal consistency.
  //
  // Tolerances are asymmetric on purpose. The z-formula is a floor; the
  // t-based truth sits 0 to 4 rounds above it, more at small n.
  // ------------------------------------------------------------------
  group('closed-form agreement on Gaussian noise', () {
    // Monte-Carlo jitter in the returned n is smallest at small n, because
    // power rises steeply there. At n ~ 34 with nSims = 10000 it is well
    // under one round; at n ~ 128 it is about 1.5 rounds.
    const sigma = 100.0;
    const nSims = 10000;

    late List<double> noise;
    setUp(() => noise = normalNoise(4000, sigma));

    /// sigma/delta -> (expected exact n, computed offline from the
    /// noncentral-t power function)
    ///   ratio 1 -> 10      (z-formula:   8)
    ///   ratio 2 -> 34      (z-formula:  32)
    ///   ratio 4 -> 128     (z-formula: 126)
    void checkRatio(double sesoi, int expectedExact) {
      const baseMean = 1000.0;
      final delta = baseMean * sesoi;
      final floor = zApproxN(
        sigma: sigma,
        delta: delta,
        zAlpha: zAlpha05,
        zPower: zPower80,
      );

      final n = calculateBootstrapSampleSize(
        diffs: noise,
        baseMean: baseMean,
        sesoi: sesoi,
        nSims: nSims,
        seed: 1,
      );

      expect(n, greaterThanOrEqualTo(floor),
          reason: 'simulation must not beat the z-formula floor of $floor');
      expect(n, closeTo(expectedExact, max(2, expectedExact * 0.08)),
          reason: 'noncentral-t truth is $expectedExact, z-formula is $floor');
    }

    test('sigma/delta = 1 -> n ~ 10', () => checkRatio(0.10, 10));
    test('sigma/delta = 2 -> n ~ 34', () => checkRatio(0.05, 34));
    test('sigma/delta = 4 -> n ~ 128', () => checkRatio(0.025, 128));

    test('n scales as 1/delta^2', () {
      const baseMean = 1000.0;
      int run(double sesoi) => calculateBootstrapSampleSize(
            diffs: noise,
            baseMean: baseMean,
            sesoi: sesoi,
            nSims: nSims,
            seed: 1,
          );

      // Halving the effect twice should multiply n by roughly 16.
      final big = run(0.10); // ~10
      final small = run(0.025); // ~128
      expect(small / big, closeTo(13, 4),
          reason: 'quadratic scaling, damped by the +2 offset at small n');
    });

    test('tighter alpha and higher power both increase n', () {
      const baseMean = 1000.0;
      const sesoi = 0.05;
      final base = calculateBootstrapSampleSize(
          diffs: noise,
          baseMean: baseMean,
          sesoi: sesoi,
          nSims: nSims,
          seed: 1); // ~34

      final tighterAlpha = calculateBootstrapSampleSize(
          diffs: noise,
          baseMean: baseMean,
          sesoi: sesoi,
          alpha: 0.01,
          nSims: nSims,
          seed: 1); // ~49
      final morePower = calculateBootstrapSampleSize(
          diffs: noise,
          baseMean: baseMean,
          sesoi: sesoi,
          power: 0.95,
          nSims: nSims,
          seed: 1); // ~54

      expect(tighterAlpha, greaterThan(base));
      expect(morePower, greaterThan(base));

      // And they should land near their own closed forms.
      expect(
          tighterAlpha,
          closeTo(
              zApproxN(
                  sigma: sigma,
                  delta: 50.0,
                  zAlpha: zAlpha01,
                  zPower: zPower80),
              6));
      expect(
          morePower,
          closeTo(
              zApproxN(
                  sigma: sigma,
                  delta: 50.0,
                  zAlpha: zAlpha05,
                  zPower: zPower95),
              6));
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  // ------------------------------------------------------------------
  // Calibration. Power is meaningless if the test is not running at the
  // alpha you asked for. These tests are DIAGNOSTIC: a failure here is a
  // real finding about your data, not a flaky assertion.
  // ------------------------------------------------------------------
  group('type-I error calibration', () {
    test('Gaussian noise rejects at ~alpha when there is no effect', () {
      final noise = normalNoise(4000, 100.0);
      for (final n in [5, 34, 200]) {
        final rate = estimatePowerAt(
          centeredNoise: noise,
          trueEffect: 0.0, // no effect: every rejection is a false positive
          nRounds: n,
          alpha: 0.05,
          nSims: 20000,
          seed: 3,
        );
        // SE at 20k sims is 0.0015, so 0.012 is ~8 sigma of slack.
        expect(rate, closeTo(0.05, 0.012), reason: 'n = $n');
      }
    });

    test('skewed noise does not blow the false-positive rate at small n', () {
      final noise = lognormalNoise(4000, 100.0);
      final rate = estimatePowerAt(
        centeredNoise: noise,
        trueEffect: 0.0,
        nRounds: 6,
        alpha: 0.05,
        nSims: 20000,
        seed: 3,
      );
      // The one-sample t-test on right-skewed data is known to mis-calibrate
      // at small n. If this fails, "80% power at n = 6" is really "80% power
      // at an inflated alpha" - switch to a permutation test or raise minN.
      expect(rate, lessThan(0.09),
          reason: 'observed alpha = $rate, nominal 0.05');
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  // ------------------------------------------------------------------
  // Reproducibility. These are the regression tests for B2 and B3: a
  // stochastic predicate under binary search used to give a different
  // answer on every run, and could return maxN spuriously.
  // ------------------------------------------------------------------
  group('determinism', () {
    final noise = normalNoise(2000, 100.0);

    test('same seed gives byte-identical results', () {
      int run() => calculateBootstrapSampleSize(
            diffs: noise,
            baseMean: 1000.0,
            sesoi: 0.05,
            nSims: 2000,
            seed: 99,
          );
      final first = run();
      expect(run(), equals(first));
      expect(run(), equals(first));
    });

    test('different seeds agree to within Monte-Carlo jitter', () {
      final results = [
        for (var s = 0; s < 6; s++)
          calculateBootstrapSampleSize(
            diffs: noise,
            baseMean: 1000.0,
            sesoi: 0.05,
            nSims: 2000,
            seed: s,
          )
      ];
      // Before the fix, an unlucky comparison could discard half the search
      // range and land far away. Spread should now be a couple of rounds.
      expect(results.reduce(max) - results.reduce(min), lessThanOrEqualTo(4),
          reason: 'seeds gave $results');
    });

    test('answer is invariant to shifting all diffs by a constant', () {
      // Only the spread of diffs matters; the observed mean effect is
      // divided out. This guards the centring step.
      final shifted = [for (final d in noise) d + 12345.0];
      expect(
        calculateBootstrapSampleSize(
            diffs: shifted,
            baseMean: 1000.0,
            sesoi: 0.05,
            nSims: 2000,
            seed: 5),
        equals(calculateBootstrapSampleSize(
            diffs: noise, baseMean: 1000.0, sesoi: 0.05, nSims: 2000, seed: 5)),
      );
    });

    test('sign of sesoi and baseMean does not matter', () {
      final n = calculateBootstrapSampleSize(
          diffs: noise, baseMean: 1000.0, sesoi: 0.05, nSims: 2000, seed: 5);
      expect(
          calculateBootstrapSampleSize(
              diffs: noise,
              baseMean: 1000.0,
              sesoi: -0.05,
              nSims: 2000,
              seed: 5),
          equals(n));
      expect(
          calculateBootstrapSampleSize(
              diffs: noise,
              baseMean: -1000.0,
              sesoi: 0.05,
              nSims: 2000,
              seed: 5),
          equals(n));
    });
  }, timeout: const Timeout(Duration(minutes: 2)));

  // ------------------------------------------------------------------
  group('boundary behaviour', () {
    final noise = normalNoise(2000, 100.0);

    test('saturates at maxN when the effect is undetectable', () {
      // sigma/delta = 1000 needs ~8 million rounds; budget is 200.
      expect(
        calculateBootstrapSampleSize(
          diffs: noise,
          baseMean: 1000.0,
          sesoi: 0.0001,
          nSims: 1000,
          seed: 1,
          maxN: 200,
        ),
        equals(200),
        reason: 'must return maxN exactly, not overshoot or loop',
      );
    });

    test('does not return maxN when the requirement is just barely met', () {
      // Regression test for B2: powerAt(high) was called twice, and the
      // second, independent roll could dip below the threshold and trip
      // the `return maxN` path. Setting maxN just above the true answer
      // makes that failure mode near-certain if it ever comes back.
      final n = calculateBootstrapSampleSize(
        diffs: noise,
        baseMean: 1000.0,
        sesoi: 0.05,
        nSims: 2000,
        seed: 1,
        maxN: 40,
      );
      expect(n, lessThan(40));
    });

    test('clamps at minN when the effect is overwhelming', () {
      expect(
        calculateBootstrapSampleSize(
            diffs: noise, baseMean: 1000.0, sesoi: 1.0, nSims: 1000, seed: 1),
        equals(kDefaultMinN),
      );
      expect(
        calculateBootstrapSampleSize(
            diffs: noise,
            baseMean: 1000.0,
            sesoi: 1.0,
            nSims: 1000,
            seed: 1,
            minN: 12),
        equals(12),
      );
    });

    test('rejects minN below the safe floor', () {
      expect(
        () => calculateBootstrapSampleSize(
            diffs: noise, baseMean: 1000.0, sesoi: 0.05, minN: 3),
        throwsArgumentError,
      );
    });
  });

  // ------------------------------------------------------------------
  group('argument validation', () {
    // Replaces the old `returns 0 if ...` test: the sentinel return was
    // indistinguishable from a legitimate answer at a glance (B8).
    final ok = normalNoise(50, 10.0);

    test('rejects degenerate diffs', () {
      expect(
          () => calculateBootstrapSampleSize(
              diffs: [], baseMean: 100.0, sesoi: 0.05),
          throwsArgumentError);
      expect(
          () => calculateBootstrapSampleSize(
              diffs: [1.0], baseMean: 100.0, sesoi: 0.05),
          throwsArgumentError);
      // Zero variance: every resample is identical, so the old code found
      // "significance" 100% of the time and confidently returned minN.
      expect(
          () => calculateBootstrapSampleSize(
              diffs: [4.0, 4.0, 4.0, 4.0], baseMean: 100.0, sesoi: 0.05),
          throwsArgumentError);
    });

    test('rejects out-of-range parameters', () {
      expect(
          () => calculateBootstrapSampleSize(
              diffs: ok, baseMean: 100.0, sesoi: 0.0),
          throwsArgumentError);
      expect(
          () => calculateBootstrapSampleSize(
              diffs: ok, baseMean: 0.0, sesoi: 0.05),
          throwsArgumentError);
      for (final p in [0.0, 1.0, -0.1, 1.5]) {
        expect(
            () => calculateBootstrapSampleSize(
                diffs: ok, baseMean: 100.0, sesoi: 0.05, power: p),
            throwsArgumentError,
            reason: 'power = $p');
      }
      for (final a in [0.0, 1.0, -0.1, 2.0]) {
        expect(
            () => calculateBootstrapSampleSize(
                diffs: ok, baseMean: 100.0, sesoi: 0.05, alpha: a),
            throwsArgumentError,
            reason: 'alpha = $a');
      }
    });
  });

  // ------------------------------------------------------------------
  // Guards B4. The Cornish-Fisher expansion is off by -23% at df = 1,
  // which matters because real pilot data lands in single-digit n.
  // ------------------------------------------------------------------
  group('studentTCriticalValue', () {
    test('exact closed forms at df 1 and 2 for arbitrary alpha', () {
      expect(studentTCriticalValue(1, 0.05), closeTo(12.7062, 5e-4));
      expect(studentTCriticalValue(2, 0.05), closeTo(4.3027, 5e-4));
      expect(studentTCriticalValue(1, 0.01), closeTo(63.6567, 5e-4));
      expect(studentTCriticalValue(2, 0.01), closeTo(9.9248, 5e-4));
      // Bonferroni for 3 comparisons - no table entry needed.
      expect(studentTCriticalValue(1, 0.05 / 3), closeTo(38.188, 2e-3));
      expect(studentTCriticalValue(2, 0.05 / 3), closeTo(7.6490, 2e-3));
    });

    test('refuses df 3 or 4 with an untabled alpha', () {
      expect(() => studentTCriticalValue(3, 0.05 / 3), throwsArgumentError);
      expect(() => studentTCriticalValue(4, 0.05 / 3), throwsArgumentError);
      // df >= 5 is fine for any alpha.
      expect(studentTCriticalValue(10, 0.05 / 3), closeTo(2.869, 0.02));
    });

    test('series is accurate for df >= 5', () {
      const truth = {
        5: 2.57058,
        10: 2.22814,
        20: 2.08596,
        30: 2.04227,
        60: 2.00030,
        120: 1.97993,
        299: 1.96793,
      };
      truth.forEach((df, t) {
        // Residual is dominated by the ~4.5e-4 error of the A&S 26.2.23
        // normal quantile, so ask for 1e-3 relative, not machine precision.
        expect(studentTCriticalValue(df, 0.05), closeTo(t, t * 1e-3),
            reason: 'df = $df');
      });
    });

    test('monotone decreasing in df, increasing as alpha shrinks', () {
      for (var df = 5; df < 200; df++) {
        expect(studentTCriticalValue(df + 1, 0.05),
            lessThan(studentTCriticalValue(df, 0.05)));
      }
      expect(studentTCriticalValue(30, 0.01),
          greaterThan(studentTCriticalValue(30, 0.05)));
    });

    test('converges to the normal quantile', () {
      expect(studentTCriticalValue(100000, 0.05), closeTo(zAlpha05, 1e-3));
    });

    test('tiny alpha does not produce NaN', () {
      // Guards B5: the old `1.0 - (1.0 - alpha/2)` round trip collapsed to
      // log(0) = -inf for alpha below ~2e-16.
      final t = studentTCriticalValue(30, 1e-15);
      expect(t.isFinite, isTrue);
      expect(t, greaterThan(10));
    });

    test('refuses small df with an untabled alpha', () {
      // A Bonferroni-corrected alpha at df <= 4 has no exact entry, and the
      // series is unusable there. Better to throw than to be 20% wrong.
      expect(() => studentTCriticalValue(2, 0.05 / 3), throwsArgumentError);
      expect(studentTCriticalValue(10, 0.05 / 3), closeTo(2.7099, 5e-3));
    });
  });

  // ------------------------------------------------------------------
  // The original pilot-data tests, with real assertions.
  // ------------------------------------------------------------------
  group('real pilot data', () {
    final pilotBase = [
      46.2,
      51.8,
      44.0,
      49.5,
      45.1,
      47.7,
      44.3,
      52.0,
      46.9,
      48.2
    ];
    final pilotA = [44.1, 48.9, 43.7, 46.0, 44.2, 45.1, 43.0, 49.4, 45.0, 46.1];
    final diffs = List<double>.generate(
        pilotBase.length, (i) => pilotA[i] - pilotBase[i]);
    final baseMean = pilotBase.reduce((a, b) => a + b) / pilotBase.length;

    test('10-round pilot needs only a handful of rounds for SESOI = 5%', () {
      // Worked out by hand: centred diffs have population SD 0.9163 and
      // Δ = 47.57 * 0.05 = 2.3785, so sigma/delta = 0.385. The z-formula
      // says 2; solving with the actual t critical values says 4.
      //
      // NOTE this is pinned near minN, so it exercises the df <= 4 branch
      // and almost nothing else. It is a smoke test, not a correctness
      // test - see the Gaussian group above for that.
      final n = calculateBootstrapSampleSize(
        diffs: diffs,
        baseMean: baseMean,
        sesoi: 0.05,
        nSims: 5000,
        seed: 42,
      );
      expect(n, kDefaultMinN /* floor-limited */);
    });

    test('smaller SESOI needs quadratically more rounds', () {
      // Rescaled from the original fixture, which had both arms clamped at
      // minN. sigma = 1.3693, so these land at roughly 370 and 17.
      final noisy = [-2.0, 1.5, -1.0, 0.5, -2.5, 1.0, -1.5, 0.0];
      const baseMean = 100.0;

      final nTiny = calculateBootstrapSampleSize(
          diffs: noisy,
          baseMean: baseMean,
          sesoi: 0.002,
          nSims: 4000,
          seed: 123);
      final nSmall = calculateBootstrapSampleSize(
          diffs: noisy,
          baseMean: baseMean,
          sesoi: 0.01,
          nSims: 4000,
          seed: 123);
      final nLarge = calculateBootstrapSampleSize(
          diffs: noisy,
          baseMean: baseMean,
          sesoi: 0.10,
          nSims: 4000,
          seed: 123);

      expect(nTiny, greaterThan(nSmall));
      expect(nSmall, greaterThan(nLarge));
      expect(nTiny, closeTo(370, 40));
      expect(nSmall, closeTo(17, 4));

      // 5x smaller effect -> ~25x more rounds (damped a little by the
      // constant t-vs-z offset, which is proportionally larger at n = 17).
      expect(nTiny / nSmall, closeTo(22, 6));
    });

    test('a coarse noise library still gives a usable answer', () {
      // 10 pilot rounds means the resampling library has only 10 distinct
      // values. That is fine for the *mean* (CLT), but the returned n
      // inherits the ~24% uncertainty of a 10-sample sigma estimate, which
      // doubles to ~48% in n. Report "about 4 rounds", never "4 rounds".
      final wide = calculateBootstrapSampleSize(
          diffs: diffs, baseMean: baseMean, sesoi: 0.02, nSims: 5000, seed: 42);
      expect(wide, inInclusiveRange(8, 20));
    });

    test('skew does not change n much when sigma is held fixed', () {
      // Power depends on sigma, so a heavier-tailed library with the same
      // spread should need a similar n. Skew shows up in *calibration*
      // (see the type-I group), not here. If this ever diverges sharply,
      // suspect the variance estimate rather than the search.
      const sigma = 100.0;
      int run(List<double> noise) => calculateBootstrapSampleSize(
          diffs: noise, baseMean: 1000.0, sesoi: 0.05, nSims: 8000, seed: 17);

      final gaussian = run(normalNoise(4000, sigma));
      final skewed = run(lognormalNoise(4000, sigma));
      expect(skewed, closeTo(gaussian, gaussian * 0.25),
          reason: 'gaussian = $gaussian, skewed = $skewed');
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}

const zAlpha01 = 2.575829; // two-tailed alpha = 0.01

const zAlpha05 = 1.959964; // two-tailed alpha = 0.05

const zPower80 = 0.841621;

const zPower95 = 1.644854;

/// Right-skewed noise with the *same* population SD as [normalNoise].
/// Shape differs, spread does not - which isolates the effect of skew.
List<double> lognormalNoise(int n, double sigma, {int seed = 11}) {
  final z = normalNoise(n, 1.0, seed: seed);
  return _normalizeTo([for (final x in z) exp(0.75 * x)], sigma);
}

/// Box-Muller normal noise, centred, with population SD exactly [sigma].
List<double> normalNoise(int n, double sigma, {int seed = 7}) {
  final rng = Random(seed);
  final out = <double>[];
  while (out.length < n) {
    final u1 = 1.0 - rng.nextDouble(); // (0, 1], so log() is finite
    final u2 = rng.nextDouble();
    final r = sqrt(-2.0 * log(u1));
    out.add(r * cos(2 * pi * u2));
    if (out.length < n) out.add(r * sin(2 * pi * u2));
  }
  return _normalizeTo(out, sigma);
}

/// Textbook closed form for a paired t-test sample size, using normal
/// quantiles: n = ((z_alpha + z_power) * sigma / delta)^2
///
/// This *under*shoots, because the real test uses t (fatter tails) rather
/// than z. The classic correction is "+2". Both bounds are asserted below.
int zApproxN({
  required double sigma,
  required double delta,
  required double zAlpha,
  required double zPower,
}) =>
    (pow((zAlpha + zPower) * sigma / delta, 2) as double).ceil();

/// Rescales [xs] to mean exactly 0 and *population* SD exactly [sigma].
///
/// The population SD is the right target: the calculator resamples with
/// replacement from this list, so the spread it actually sees is the
/// population SD of the list, not the (n-1)-corrected sample SD.
///
/// Pinning sigma exactly is what makes the assertions below tight. A random
/// draw of 2000 normals has a ~1.6% SD error, which propagates to ~3.2% in n.
List<double> _normalizeTo(List<double> xs, double sigma) {
  final mean = xs.reduce((a, b) => a + b) / xs.length;
  var ss = 0.0;
  for (final x in xs) {
    ss += (x - mean) * (x - mean);
  }
  final popSd = sqrt(ss / xs.length);
  return [for (final x in xs) (x - mean) * sigma / popSd];
}
