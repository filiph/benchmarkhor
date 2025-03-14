import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:t_stats/t_stats.dart';

class BenchmarkResult {
  final String name;

  final Uint32List _rawMeasurements;

  final int exercisesCount;

  final int iterationsPerExercise;

  late final List<double> _measurements = _rawMeasurements
      .map((m) => m / iterationsPerExercise)
      .toList(growable: false);

  late final UnmodifiableListView<double> measurements =
      UnmodifiableListView(_measurements);

  late final Statistic statistic = Statistic.from(measurements, name: name);

  late final Statistic statisticLogNormal =
      Statistic.from(measurements.map((m) => math.log(m)), name: "$name (log)");

  BenchmarkResult({
    required this.name,
    required Uint32List measurements,
    required this.exercisesCount,
    required this.iterationsPerExercise,
  })  : _rawMeasurements = measurements,
        assert(measurements.length == exercisesCount);
}
