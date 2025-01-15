import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';

void main() {
  final baseline = BaselineBenchmark().measure();
  final clazz = ClassBenchmark().measure();
  final record = RecordBenchmark().measure();

  print('Class: ${clazz / baseline}x');
  print('Record: ${record / baseline}x');

  print('---');
  print('Record is: ${((record / clazz - 1) * 100).round()}% slower.');

  BaselineBenchmark().report();
  ClassBenchmark().report();
  RecordBenchmark().report();
  exitCode = 0;
  return;
}

typedef Record = ({double real, int integer, String string});

final class BaselineBenchmark extends _BaseBenchmark {
  late final List<int> _store = List.filled(count, 0);

  BaselineBenchmark() : super('Baseline');

  @override
  void run() {
    for (var i = 0; i < count; i++) {
      _store[i] = getInt();
    }
  }

  @override
  void teardown() {
    exitCode = _store.last;
  }
}

final class ClassBenchmark extends _BaseBenchmark {
  late final List<Clazz> _store =
      List.filled(count, Clazz(real: 0, integer: 0, string: ''));

  ClassBenchmark() : super('Class');

  @override
  void run() {
    for (var i = 0; i < count; i++) {
      _store[i] = getClass();
    }
  }

  @override
  void teardown() {
    exitCode = _store.last.integer;
  }
}

final class Clazz {
  final double real;
  final int integer;
  final String string;

  const Clazz(
      {required this.real, required this.integer, required this.string});
}

final class RecordBenchmark extends _BaseBenchmark {
  late final List<Record> _store =
      List.filled(count, (real: 0, integer: 0, string: ''));

  RecordBenchmark() : super('Record');

  @override
  void run() {
    for (var i = 0; i < count; i++) {
      _store[i] = getRecord();
    }
  }

  @override
  void teardown() {
    exitCode = _store.last.integer;
  }
}

sealed class _BaseBenchmark extends BenchmarkBase {
  final int count = 1000;

  int _counter = 0;

  _BaseBenchmark(super.name);

  @override
  void exercise() => run();

  Clazz getClass() => switch (_counter++ % 2) {
        0 => Clazz(real: 3.14, integer: 42, string: "hello"),
        1 => Clazz(real: -0.0, integer: 1337, string: "こんにちは世界"),
        _ => throw 'Unreachable',
      };

  int getInt() => switch (_counter++ % 2) {
        0 => 1,
        1 => 2,
        _ => throw 'Unreachable',
      };

  Record getRecord() => switch (_counter++ % 2) {
        0 => (real: 3.14, integer: 42, string: "hello"),
        1 => (real: -0.0, integer: 1337, string: "こんにちは世界"),
        _ => throw 'Unreachable',
      };
}
