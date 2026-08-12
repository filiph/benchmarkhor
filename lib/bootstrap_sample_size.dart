import 'dart:math';

import 'package:meta/meta.dart';

/// Exact two-tailed critical values for df = 3 and 4, where no elementary
/// closed form exists and the Cornish-Fisher series is still poor
/// (-0.7% at df=3 for alpha=0.05, -3.3% for alpha=0.01).
///
/// Keyed by the exact alpha double, NOT by a rounded integer. Rounding
/// (e.g. `(alpha * 100).round()`) collides: alpha=0.011 would round to 1
/// and silently return the alpha=0.01 row, which is ~2% wrong with no
/// error. An exact key means a near-miss alpha throws instead.
final _exactDf3And4 = <double, List<double>>{
  0.10: [2.3534, 2.1318],
  0.05: [3.1824, 2.7764],
  0.01: [5.8409, 4.6041],
};

/// Default floor for the search. 6 rounds means df >= 5, which keeps the
/// t critical value in the range where the series approximation is reliable
/// for any alpha. Do not lower this.
const kDefaultMinN = 6;

const kDefaultMaxN = 10000;

/// Below this many distinct values in the noise library,
/// [calibratedCriticalValue] is estimating a quantile
/// from too few underlying points to be trustworthy.
const _minDistinctForCalibration = 8;

/// Two-tailed Student's t critical value for [df] degrees of freedom
/// at significance level [alpha].
///
/// Exact for df = 1 and 2 (closed forms, any alpha). Exact table lookup for
/// df = 3 and 4 at the tabulated alphas only. Accurate to ~2e-4 relative
/// for df >= 5, where the Cornish-Fisher series is usable.
double studentTCriticalValue(int df, double alpha) {
  if (df < 1) return double.infinity;
  if (alpha <= 0 || alpha >= 1) {
    throw ArgumentError.value(alpha, 'alpha', 'must be in (0, 1)');
  }

  // Exact for any alpha.
  if (df == 1) return 1.0 / tan(pi * alpha / 2.0);
  if (df == 2) return (1.0 - alpha) * sqrt(2.0 / (alpha * (2.0 - alpha)));

  if (df <= 4) {
    final row = _exactDf3And4[alpha];
    if (row != null) return row[df - 3];
    throw ArgumentError(
      'studentTCriticalValue: df=$df with alpha=$alpha is not tabulated, '
      'and the series approximation is unusable below df=5 (off by -3.3% at '
      'df=3, alpha=0.01). Use minN >= $kDefaultMinN so that df >= 5, or add '
      'a row to _exactDf3And4. Note that the lookup requires an exact '
      'double match: 0.05 works, 1 - 0.95 does not.',
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

/// Sample skewness (Fisher-Pearson, bias-corrected).
///
/// Use this to decide whether you need `calibrated: true`. Rules of thumb
/// for the paired per-round differences of an interleaved benchmark:
///
/// * |skew| < 0.5  - the plain t-test is fine at n >= 6.
/// * 0.5 to 1.0    - mild inflation of the false-positive rate; calibrate
///                   if you care about small n.
/// * > 1.0         - calibrate. At skew ~3.3 and n = 6 the nominal 5% test
///                   actually fires ~13% of the time.
///
/// Paired differences are usually far less skewed than either arm, because
/// subtracting two similarly-shaped distributions cancels most of the skew.
/// Measure it rather than assuming either way.
double skewness(List<double> xs) {
  final n = xs.length;
  if (n < 3) {
    throw ArgumentError.value(xs, 'xs', 'needs at least 3 values');
  }

  var mean = 0.0;
  for (final x in xs) {
    mean += x;
  }
  mean /= n;

  var m2 = 0.0, m3 = 0.0;
  for (final x in xs) {
    final d = x - mean;
    m2 += d * d;
    m3 += d * d * d;
  }
  m2 /= n;
  m3 /= n;
  if (m2 == 0) return 0.0;

  return sqrt(n * (n - 1)) / (n - 2) * m3 / pow(m2, 1.5);
}

/// |t| of [sample] tested against zero, via Welford's algorithm.
/// Bessel-corrected variance. Returns infinity for a constant, non-zero
/// sample: an apparently infinite signal-to-noise ratio.
double _absT(List<double> sample) {
  final n = sample.length;
  if (n < 2) return 0.0;

  var mean = 0.0, m2 = 0.0;
  for (var i = 0; i < n; i++) {
    final x = sample[i];
    final delta = x - mean;
    mean += delta / (i + 1);
    m2 += delta * (x - mean);
  }
  final variance = m2 / (n - 1);
  if (variance <= 0) return mean == 0 ? 0.0 : double.infinity;

  return (mean / sqrt(variance / n)).abs();
}

/// Empirical critical value of |t| under the null hypothesis, obtained by
/// resampling [centeredNoise] at [nRounds] (the bootstrap-t, or studentized
/// bootstrap).
///
/// The point: [studentTCriticalValue] assumes the differences are normally
/// distributed. When they are skewed, the sample mean and the sample SD are
/// correlated, the t statistic is not Student-t distributed, and at small n
/// there is not enough data for the CLT to rescue you. The test then rejects
/// far more often than alpha claims. This function measures the actual
/// distribution of |t| for the shape of *your* data instead of assuming one,
/// so it holds alpha under skew. It generally returns a LARGER critical value
/// than the parametric one, hence larger and more honest sample sizes.
///
/// Three limits worth knowing:
///
/// * It cannot outrun a small pilot. With 10 pilot rounds the library has 10
///   distinct values and the quantile is itself noisy. This corrects shape
///   misspecification, not insufficient data. Below
///   [_minDistinctForCalibration] distinct values it declines and falls back.
/// * The symmetric |t| region is still an approximation under skew. An
///   equal-tailed version (separate quantiles of the *signed* t) is more
///   accurate if you want to push further.
/// * Monte Carlo error in the quantile is roughly +/-0.5% of alpha at
///   nSims = 20000. Don't drop nSims much below that.
///
/// Deterministic in ([nRounds], [seed]), and drawn from an RNG stream
/// disjoint from the one [estimatePowerAt] uses, so the critical value and
/// the rejections it judges are independent.
@visibleForTesting
double calibratedCriticalValue({
  required List<double> centeredNoise,
  required int nRounds,
  double alpha = 0.05,
  int nSims = 20000,
  int seed = 0,
}) {
  if (nRounds < 2) return double.infinity;
  if (alpha <= 0 || alpha >= 1) {
    throw ArgumentError.value(alpha, 'alpha', 'must be in (0, 1)');
  }

  // Too few distinct values to estimate a tail quantile from. Fall back to
  // the parametric value rather than returning a confidently wrong number.
  if (centeredNoise.toSet().length < _minDistinctForCalibration) {
    return studentTCriticalValue(nRounds - 1, alpha);
  }

  final rng = Random(0x5bf03635 ^ (seed * 7919 + nRounds * 104729));
  final ts = List<double>.filled(nSims, 0.0);
  final fake = List<double>.filled(nRounds, 0.0);

  for (var sim = 0; sim < nSims; sim++) {
    for (var i = 0; i < nRounds; i++) {
      fake[i] = centeredNoise[rng.nextInt(centeredNoise.length)];
    }
    ts[sim] = _absT(fake);
  }
  ts.sort();

  // Order statistic k such that (nSims - 1 - k) / nSims ~= alpha, i.e. the
  // fraction of the null distribution strictly above the returned value is
  // alpha. Accurate to O(1 / nSims); ties make it slightly conservative.
  final k = (((1.0 - alpha) * nSims).ceil() - 1).clamp(0, nSims - 1);
  final crit = ts[k];

  // A non-finite quantile means most resamples were constant (a degenerate
  // pilot, e.g. two distinct values). Fall back rather than report zero power
  // forever, which would send the search straight to maxN.
  return crit.isFinite ? crit : studentTCriticalValue(nRounds - 1, alpha);
}

/// Fraction of simulated experiments of [nRounds] rounds that detect
/// [trueEffect], given a library of [centeredNoise] to resample from.
///
/// Deterministic in ([nRounds], [seed]): the RNG is derived from both, so
/// repeated calls at the same n return the identical estimate. The binary
/// search in [calculateBootstrapSampleSize] relies on this.
///
/// Pass `trueEffect: 0` to measure the type-I error rate instead of power.
/// With [calibrated] true that rate comes out at alpha by construction, which
/// is the whole point; with it false you can see how far off the parametric
/// assumption is for your data.
///
/// [calibrated] roughly doubles the cost (one extra simulation pass to find
/// the critical value). Callers doing a search over n should memoize per n.
@visibleForTesting
double estimatePowerAt({
  required List<double> centeredNoise,
  required double trueEffect,
  required int nRounds,
  double alpha = 0.05,
  int nSims = 5000,
  int seed = 0,
  bool calibrated = false,
  int nCalibrationSims = 20000,
}) {
  if (nRounds < 2) return 0.0;
  final rng = Random(seed * 1000003 + nRounds);

  final tCrit = calibrated
      ? calibratedCriticalValue(
          centeredNoise: centeredNoise,
          nRounds: nRounds,
          alpha: alpha,
          nSims: nCalibrationSims,
          seed: seed,
        )
      : studentTCriticalValue(nRounds - 1, alpha);

  final fake = List<double>.filled(nRounds, 0.0);

  var wins = 0;
  for (var sim = 0; sim < nSims; sim++) {
    for (var i = 0; i < nRounds; i++) {
      fake[i] = trueEffect + centeredNoise[rng.nextInt(centeredNoise.length)];
    }
    if (_absT(fake) > tCrit) wins++;
  }
  return wins / nSims;
}

/// Minimum number of rounds needed to detect an effect of [sesoi]
/// (as a fraction of [baseMean]) with the given [power] and [alpha].
///
/// [diffs] are the paired per-round differences. Returns [maxN] if the
/// requirement cannot be met within that budget, so check for that.
///
/// Set [calibrated] true when the differences are skewed (check with
/// [skewness]); it holds the false-positive rate at [alpha] instead of
/// letting it drift upward, at the cost of a larger recommended n and
/// roughly double the runtime. See [calibratedCriticalValue].
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
  int minN = kDefaultMinN,
  int maxN = kDefaultMaxN,
  bool calibrated = false,
  int nCalibrationSims = 20000,
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
  // which is what makes the binary search below well-defined. The cache also
  // stops `calibrated` from re-deriving the critical value at a repeated n.
  double powerAt(int nRounds) => cache.putIfAbsent(
        nRounds,
        () => estimatePowerAt(
          centeredNoise: noise,
          trueEffect: trueEffect,
          nRounds: nRounds,
          alpha: alpha,
          nSims: nSims,
          seed: seed,
          calibrated: calibrated,
          nCalibrationSims: nCalibrationSims,
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
