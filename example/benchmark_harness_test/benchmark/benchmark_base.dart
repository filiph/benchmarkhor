import 'dart:math' as math;
import 'dart:typed_data';

import 'benchmark_result.dart';
import 'score_emitter.dart';

const int minimumMeasureDurationMillis = 2000;

class BenchmarkBase {
  static const warmupDuration = Duration(milliseconds: 10);

  final String name;
  final ScoreEmitter emitter;

  const BenchmarkBase(this.name, {this.emitter = const PrintEmitter()});

  /// The benchmark code.
  void run() {}

  /// Runs a short version of the benchmark. By default invokes [run] once.
  void warmup() {
    final watch = Stopwatch()..start();
    do {
      run();
    } while (watch.elapsed < warmupDuration);
    watch.stop();
  }

  /// Exercises the benchmark. By default invokes [run] 10 times.
  @Deprecated('Use run instead')
  void exercise() {
    for (var i = 0; i < 10; i++) {
      run();
    }
  }

  /// Not measured setup code executed prior to the benchmark runs.
  void setup() {}

  /// Not measured teardown code executed after the benchmark runs.
  void teardown() {}

  /// Measures the score for this benchmark by executing it enough times
  /// to reach [minimumMillis].

  /// Measures the score for this benchmark by executing it repeatedly until
  /// time minimum has been reached.
  static double measureFor(void Function() f, int minimumMillis) =>
      measureForImpl(f, minimumMillis).score;

  /// Measures the score for the benchmark and returns it.
  Future<BenchmarkResult> measureAsync(
      {int? exercises, int? perExercise}) async {
    setup();

    if (exercises == null || perExercise == null) {
      final (exercises: computedExercises, perExercise: computedPerExercise) =
          _estimateIterationsFor(
        const Duration(milliseconds: minimumMeasureDurationMillis),
        warmupDuration: warmupDuration,
      );
      exercises ??= computedExercises;
      perExercise ??= computedPerExercise;
    } else {
      warmup();
    }

    final measurements = Uint32List(exercises);
    final watch = Stopwatch()..start();
    for (var i = 0; i < exercises; i++) {
      watch.reset();
      for (var i = 0; i < perExercise; i++) {
        run();
      }
      // Give the benchmark a chance to do some work (like GC).
      await Future<void>.delayed(Duration.zero);
      final elapsed = watch.elapsedMicroseconds;
      measurements[i] = elapsed;
    }

    teardown();

    return BenchmarkResult(
      name: name,
      measurements: measurements,
      exercisesCount: exercises,
      iterationsPerExercise: perExercise,
    );
  }

  /// Measures the score for the benchmark and returns it.
  BenchmarkResult measure({int? exercises, int? perExercise}) {
    setup();

    if (exercises == null || perExercise == null) {
      final (exercises: computedExercises, perExercise: computedPerExercise) =
          _estimateIterationsFor(
        const Duration(milliseconds: minimumMeasureDurationMillis),
        warmupDuration: warmupDuration,
      );
      exercises ??= computedExercises;
      perExercise ??= computedPerExercise;
    } else {
      warmup();
    }

    final measurements = Uint32List(exercises);
    final watch = Stopwatch()..start();
    for (var i = 0; i < exercises; i++) {
      watch.reset();
      for (var i = 0; i < perExercise; i++) {
        run();
      }
      final elapsed = watch.elapsedMicroseconds;
      measurements[i] = elapsed;
    }

    teardown();

    return BenchmarkResult(
      name: name,
      measurements: measurements,
      exercisesCount: exercises,
      iterationsPerExercise: perExercise,
    );
  }

  BenchmarkResult report() {
    final result = measure(exercises: 1000, perExercise: 100);
    emitter.emit(name, result);
    return result;
  }

  Future<BenchmarkResult> reportAsync() async {
    final result = await measureAsync(exercises: 1000, perExercise: 100);
    emitter.emit(name, result);
    return result;
  }

  ({int exercises, int perExercise}) _estimateIterationsFor(
    Duration targetDuration, {
    required Duration warmupDuration,
    Duration minimumExerciseDuration = const Duration(milliseconds: 5),
  }) {
    var iter = 2;
    var totalIterations = iter;
    var totalMicros = 0;
    final watch = Stopwatch()..start();
    while (true) {
      watch.reset();
      for (var i = 0; i < iter; i++) {
        run();
      }
      final elapsed = watch.elapsedMicroseconds;
      totalMicros += elapsed;
      final measurement = Measurement(elapsed, iter, totalIterations);
      if (totalMicros >= warmupDuration.inMicroseconds) {
        final exercisesPerTest =
            totalMicros / minimumExerciseDuration.inMicroseconds;
        // TODO: quantize so it's something like 10, 20, 50, not 43
        final iterationsPerExercise =
            (totalIterations / exercisesPerTest).ceil();
        final microsPerIteration = totalMicros / totalIterations;
        // TODO: quantize so it's something like 10,000, not 43532
        final iterations = targetDuration.inMicroseconds / microsPerIteration;
        final exercises = (iterations / iterationsPerExercise).ceil();
        return (exercises: exercises, perExercise: iterationsPerExercise);
      }

      const bufferMicros = 1000;
      iter = measurement.estimateIterationsNeededToReach(
          minimumMicros:
              warmupDuration.inMicroseconds - totalMicros + bufferMicros);
      totalIterations += iter;
    }
  }
}

/// Measures the score for this benchmark by executing it enough times
/// to reach [minimumMillis].
Measurement measureForImpl(void Function() f, int minimumMillis) {
  final minimumMicros = minimumMillis * 1000;
  // If running a long measurement permit some amount of measurement jitter
  // to avoid discarding results that are almost good, but not quite there.
  final allowedJitter =
      minimumMillis < 1000 ? 0 : (minimumMicros * 0.1).floor();
  var iter = 2;
  var totalIterations = iter;
  final watch = Stopwatch()..start();
  while (true) {
    watch.reset();
    for (var i = 0; i < iter; i++) {
      f();
    }
    final elapsed = watch.elapsedMicroseconds;
    final measurement = Measurement(elapsed, iter, totalIterations);
    if (measurement.elapsedMicros >= (minimumMicros - allowedJitter)) {
      return measurement;
    }

    iter = measurement.estimateIterationsNeededToReach(
        minimumMicros: minimumMicros);
    totalIterations += iter;
  }
}

class Measurement {
  final int elapsedMicros;
  final int iterations;
  final int totalIterations;

  Measurement(this.elapsedMicros, this.iterations, this.totalIterations);

  double get score => elapsedMicros / iterations;

  int estimateIterationsNeededToReach({required int minimumMicros}) {
    final elapsed = roundDownToMillisecond(elapsedMicros);
    return elapsed == 0
        ? iterations * 1000
        : (iterations * math.max(minimumMicros / elapsed, 1.5)).ceil();
  }

  static int roundDownToMillisecond(int micros) => (micros ~/ 1000) * 1000;

  @override
  String toString() => '$elapsedMicros in $iterations iterations';
}
