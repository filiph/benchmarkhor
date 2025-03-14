import 'dart:typed_data';

class BenchmarkResult {
  final Uint32List measurements;

  final int exercisesCount;

  final int iterationsPerExercise;

  double get averageScore =>
      measurements.fold(0, (prev, next) => prev + next) /
      exercisesCount /
      iterationsPerExercise;

  BenchmarkResult({
    required this.measurements,
    required this.exercisesCount,
    required this.iterationsPerExercise,
  }) : assert(measurements.length == exercisesCount);
}
