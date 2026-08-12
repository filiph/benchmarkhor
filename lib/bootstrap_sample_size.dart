import 'dart:math';

import 'package:t_stats/t_stats.dart';

/// Calculates Student's t critical value for two-tailed test with degrees of freedom [df]
/// and significance level [alpha].
double studentTCriticalValue(int df, double alpha) {
  if (df < 1) return double.infinity;
  final pTail = 1.0 - alpha / 2.0;

  // Abramowitz & Stegun formula for normal quantile z
  final y = sqrt(-2.0 * log(1.0 - pTail));
  const c0 = 2.515517;
  const c1 = 0.802853;
  const c2 = 0.010328;
  const d1 = 1.432788;
  const d2 = 0.189269;
  const d3 = 0.001308;

  final z = y - ((c2 * y + c1) * y + c0) / (((d3 * y + d2) * y + d1) * y + 1.0);

  // Cornish-Fisher expansion for Student's t quantile
  final z2 = z * z;
  final z3 = z2 * z;
  final z5 = z3 * z2;
  final z7 = z5 * z2;

  final term1 = (z3 + z) / (4.0 * df);
  final term2 = (5.0 * z5 + 16.0 * z3 + 3.0 * z) / (96.0 * df * df);
  final term3 = (3.0 * z7 + 19.0 * z5 + 17.0 * z3 - 15.0 * z) / (384.0 * df * df * df);

  return z + term1 + term2 + term3;
}

/// Evaluates if a 1-sample t-test on [sample] against population mean 0 is statistically
/// significant at level [alpha] (two-tailed p < alpha).
bool isOneSampleTTestSignificant(List<double> sample, double alpha) {
  final n = sample.length;
  if (n < 2) return false;

  final stats = Statistic.from(sample);
  final mean = stats.mean.toDouble();
  final stdDev = stats.stdDeviation.toDouble();

  if (stdDev == 0) {
    return mean != 0;
  }

  final se = stdDev / sqrt(n);
  final tStat = (mean / se).abs();
  final tCrit = studentTCriticalValue(n - 1, alpha);

  return tStat > tCrit;
}

/// Calculates the minimum suggested sample size (number of rounds) required
/// to detect an effect size of interest ([sesoi]) with target statistical [power]
/// and false positive rate ([alpha]), using bootstrap simulation.
///
/// [diffs] is the list of paired differences between variant and baseline.
/// [baseMean] is the mean of the baseline variant data.
/// [sesoi] is the smallest effect size of interest as a fraction (e.g. 0.05 for 5%).
/// [alpha] is the significance level / false positive rate (default 0.05).
/// [power] is the target statistical power (default 0.80).
/// [nSims] is the number of bootstrap simulations per candidate sample size (default 2000).
/// [random] is an optional [Random] instance for reproducibility.
int calculateBootstrapSampleSize({
  required List<double> diffs,
  required double baseMean,
  required double sesoi,
  double alpha = 0.05,
  double power = 0.80,
  int nSims = 2000,
  Random? random,
}) {
  if (diffs.isEmpty || baseMean == 0 || sesoi == 0) {
    return 0;
  }

  final rng = random ?? Random();

  // Noise library: differences with any real mean effect removed (centered at zero).
  final meanDiff = Statistic.from(diffs).mean.toDouble();
  final noise = diffs.map((d) => d - meanDiff).toList(growable: false);

  // True effect size injected into fake experiments.
  final trueEffect = baseMean * sesoi;

  // Function to evaluate power at candidate nRounds.
  double powerAt(int nRounds) {
    if (nRounds <= 1) return 0.0;
    var wins = 0;

    for (var sim = 0; sim < nSims; sim++) {
      final fake = List<double>.generate(
        nRounds,
        (_) => trueEffect + noise[rng.nextInt(noise.length)],
        growable: false,
      );

      if (isOneSampleTTestSignificant(fake, alpha)) {
        wins++;
      }
    }
    return wins / nSims;
  }

  const minN = 2;
  const maxN = 10000;

  // Check initial anchor n = 10
  if (powerAt(10) >= power) {
    var low = minN;
    var high = 10;
    var result = 10;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (powerAt(mid) >= power) {
        result = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return result;
  }

  // Exponential search upwards to find upper bound
  var low = 10;
  var high = 20;

  while (high < maxN && powerAt(high) < power) {
    low = high;
    high = min(high * 2, maxN);
  }

  if (powerAt(high) < power) {
    return maxN;
  }

  // Binary search between low and high
  var result = high;
  while (low <= high) {
    final mid = (low + high) ~/ 2;
    if (powerAt(mid) >= power) {
      result = mid;
      high = mid - 1;
    } else {
      low = mid + 1;
    }
  }

  return result;
}
