import 'dart:math';

import 'package:meta/meta.dart';

/// Exact two-tailed critical values for df = 3 and 4, where no elementary
/// closed form exists and the Cornish-Fisher series is still poor
/// (-0.7% at df=3 for alpha=0.05, -3.3% for alpha=0.01).
/// Keyed by alpha times 100 (e.g. 5 -> 0.05).
const _exactDf3And4 = <int, List<double>>{
  10: [2.3534, 2.1318],
  5: [3.1824, 2.7764],
  1: [5.8409, 4.6041],
};

/// Default floor for the search. 6 rounds means df >= 5, which keeps the
/// t critical value in the range where the series approximation is reliable
/// for any alpha. Do not lower this.
const kDefaultMinN = 6;

/// Two-tailed Student's t critical value for [df] degrees of freedom
/// at significance level [alpha].
///
/// Accurate to ~2e-4 relative for df >= 5. Values for df <= 4 are exact
/// table lookups, because the Cornish-Fisher series diverges there.
double studentTCriticalValue(int df, double alpha) {
  if (df < 1) return double.infinity;
  if (alpha <= 0 || alpha >= 1) {
    throw ArgumentError.value(alpha, 'alpha', 'must be in (0, 1)');
  }

  // Exact for any alpha.
  if (df == 1) return 1.0 / tan(pi * alpha / 2.0);
  if (df == 2) return (1.0 - alpha) * sqrt(2.0 / (alpha * (2.0 - alpha)));

  if (df <= 4) {
    final row = _exactDf3And4[(alpha * 100).round()];
    if (row != null) return row[df - 3];
    throw ArgumentError(
      'studentTCriticalValue: df=$df with alpha=$alpha is not tabulated, '
      'and the series approximation is unusable below df=5 (off by -3.3% at '
      'df=3, alpha=0.01). Raise minN to 6, or add a row to _exactDf3And4.',
    );
  }

  // Abramowitz & Stegun 26.2.23: upper-tail normal quantile for tail
  // probability alpha/2. No 1-(1-x) round trip.
  final y = sqrt(-2.0 * log(alpha / 2.0));
  const c0 = 2.515517, c1 = 0.802853, c2 = 0.010328;
  const d1 = 1.432788, d2 = 0.189269, d3 = 0.001308;
  final z = y - ((c2 * y + c1) * y + c0) / (((d3 * y + d2) * y + d1) * y + 1.0);

  // Abramowitz & Stegun 26.7.5: Cornish-Fisher expansion.
  final z2 = z * z, z3 = z * z * z;
  final z5 = z3 * z2, z7 = z5 * z2;
  final v = df.toDouble();
  return z +
      (z3 + z) / (4.0 * v) +
      (5.0 * z5 + 16.0 * z3 + 3.0 * z) / (96.0 * v * v) +
      (3.0 * z7 + 19.0 * z5 + 17.0 * z3 - 15.0 * z) / (384.0 * v * v * v);
}

/// One-sample t-test of [sample] against 0, using a precomputed [tCrit].
/// Mean and variance via Welford's algorithm; variance is Bessel-corrected.
bool _isSignificant(List<double> sample, double tCrit) {
  final n = sample.length;
  if (n < 2) return false;

  var mean = 0.0, m2 = 0.0;
  for (var i = 0; i < n; i++) {
    final x = sample[i];
    final delta = x - mean;
    mean += delta / (i + 1);
    m2 += delta * (x - mean);
  }
  final variance = m2 / (n - 1);
  if (variance <= 0) return mean != 0;

  return (mean / sqrt(variance / n)).abs() > tCrit;
}

/// Fraction of simulated experiments of [nRounds] rounds that detect
/// [trueEffect], given a library of [centeredNoise] to resample from.
///
/// Deterministic in ([nRounds], [seed]): the RNG is derived from both, so
/// repeated calls at the same n return the identical estimate. The binary
/// search in [calculateBootstrapSampleSize] relies on this.
///
/// Pass `trueEffect: 0` to measure the type-I error rate instead of power.
@visibleForTesting
double estimatePowerAt({
  required List<double> centeredNoise,
  required double trueEffect,
  required int nRounds,
  double alpha = 0.05,
  int nSims = 5000,
  int seed = 0,
}) {
  if (nRounds < 2) return 0.0;
  final rng = Random(seed * 1000003 + nRounds);
  final tCrit = studentTCriticalValue(nRounds - 1, alpha);
  final fake = List<double>.filled(nRounds, 0.0);

  var wins = 0;
  for (var sim = 0; sim < nSims; sim++) {
    for (var i = 0; i < nRounds; i++) {
      fake[i] = trueEffect + centeredNoise[rng.nextInt(centeredNoise.length)];
    }
    if (_isSignificant(fake, tCrit)) wins++;
  }
  return wins / nSims;
}

/// Minimum number of rounds needed to detect an effect of [sesoi]
/// (as a fraction of [baseMean]) with the given [power] and [alpha].
///
/// [diffs] are the paired per-round differences. Returns [maxN] if the
/// requirement cannot be met within that budget, so check for that.
///
/// Assumes rounds are independent; if your measurements drift over time
/// (thermal, cache warmth), the true requirement will be higher.
int calculateBootstrapSampleSize({
  required List<double> diffs,
  required double baseMean,
  required double sesoi,
  double alpha = 0.05,
  double power = 0.80,
  int nSims = 5000,
  int seed = 0,
  int minN = 6,
  int maxN = 10000,
}) {
  if (diffs.length < 2) {
    throw ArgumentError.value(diffs, 'diffs', 'needs at least 2 values');
  }
  if (minN < kDefaultMinN) {
    throw ArgumentError.value(minN, 'minN', 'must be >= $kDefaultMinN');
  }
  if (maxN < minN) {
    throw ArgumentError.value(maxN, 'maxN', 'must be >= minN ($minN)');
  }
  if (baseMean == 0) throw ArgumentError.value(baseMean, 'baseMean', '!= 0');
  if (sesoi == 0) throw ArgumentError.value(sesoi, 'sesoi', '!= 0');
  if (power <= 0 || power >= 1) {
    throw ArgumentError.value(power, 'power', 'must be in (0, 1)');
  }

  // Noise library: real effect removed, so the library is centered at zero.
  var sum = 0.0;
  for (final d in diffs) {
    sum += d;
  }
  final meanDiff = sum / diffs.length;
  final noise = [for (final d in diffs) d - meanDiff];

  if (noise.every((d) => d == 0.0)) {
    throw ArgumentError.value(diffs, 'diffs', 'zero variance');
  }

  final trueEffect = (baseMean * sesoi).abs();
  final cache = <int, double>{};

  // Deterministic in nRounds: same input always gives the same answer,
  // which is what makes the binary search below well-defined.
  double powerAt(int nRounds) => cache.putIfAbsent(
        nRounds,
        () => estimatePowerAt(
          centeredNoise: noise,
          trueEffect: trueEffect,
          nRounds: nRounds,
          alpha: alpha,
          nSims: nSims,
          seed: seed,
        ),
      );

  // Exponential search for an upper bound, then binary search.
  var low = minN;
  var high = minN;
  while (powerAt(high) < power) {
    if (high >= maxN) return maxN;
    low = high;
    high = min(high * 2, maxN);
  }

  var result = high;
  while (low <= high) {
    final mid = low + (high - low) ~/ 2;
    if (powerAt(mid) >= power) {
      result = mid;
      high = mid - 1;
    } else {
      low = mid + 1;
    }
  }
  return result;
}
