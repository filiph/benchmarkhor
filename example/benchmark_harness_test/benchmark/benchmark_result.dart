import 'dart:typed_data';

import 'package:t_stats/t_stats.dart';

class BenchmarkResult {
  final String name;

  final Uint32List measurements;

  final int exercisesCount;

  final int iterationsPerExercise;

  late final Statistic statistic =
      Statistic.from(measurements.map((m) => m / iterationsPerExercise));

  BenchmarkResult({
    required this.name,
    required this.measurements,
    required this.exercisesCount,
    required this.iterationsPerExercise,
  }) : assert(measurements.length == exercisesCount);
}
