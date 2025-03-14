import 'package:benchmarkhor/comparison.dart';
import 'package:t_stats/t_stats.dart';

import 'benchmark_result.dart';
import 'score_emitter.dart';

final class HistogramEmitter extends ScoreEmitter {
  @override
  void emit(String testName, BenchmarkResult result,
      {String metric = 'RunTime', String unit = 'us'}) {
    print(_createAsciiVisualization(result.measurements));
    print('Ran ${result.exercisesCount} exercises, '
        '${result.iterationsPerExercise} iterations per exercise.');
    final statistic =
        Statistic.from(result.measurements, name: "$testName $metric");
    print(statistic.toString());
  }

  static String _createAsciiVisualization(List<int> measurements) {
    final buf = StringBuffer();

    final histogram = Histogram(measurements);

    // We want a bucket for the exact middle of the range.
    assert(Histogram.bucketCount.isOdd);
    // Number of characters on each side of the center line.
    const sideSize = (Histogram.bucketCount - 1) ~/ 2;

    // How many characters should the largest bucket be high?
    const height = 20;

    for (var row = 1; row <= height; row++) {
      for (var column = 0; column < Histogram.bucketCount; column++) {
        final value = histogram.bucketsNormalized[column];
        if (value > (height - row + 0.5) / height) {
          // Definitely above the line.
          buf.write('█');
        } else if (value > (height - row + 0.05) / height) {
          // Meaningfully above the line.
          buf.write('▄');
        } else if (value > (height - row) / height && row == height) {
          // A tiny bit above the line, and also at the very bottom
          // of the graph (just above the axis). We show a dot here so that
          // this information isn't completely lost, even if it was just
          // one measurement.
          buf.write('.');
        } else {
          buf.write(' ');
        }
      }
      buf.writeln();
    }

    buf.writeln('─' * Histogram.bucketCount);

    final boundValueString =
        '${(histogram.lowestBound / 1000).abs().toStringAsFixed(1)}ms';

    buf.writeln('-${boundValueString.padRight(sideSize - 1)}'
        '^'
        '${boundValueString.padLeft(sideSize)}');

    return buf.toString();
  }
}
