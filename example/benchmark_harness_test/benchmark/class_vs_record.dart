import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';

void main() {
  final baseline = BaselineBenchmark().measure();
  final clazz = ClassBenchmark().measure();
  final record = RecordBenchmark().measure();

  print('Class: ${clazz / baseline}x');
  print('Record: ${record / baseline}x');

  return;
  BaselineBenchmark().report();
  BaselineBenchmark().report();
  Baseline2Benchmark().report();
  ClassBenchmark().report();
  RecordBenchmark().report();
  exitCode = 0;
}

typedef Record = ({double real, int integer, String string});

final class Baseline2Benchmark extends _BaseBenchmark {
  int _integerStore = 0;
  double _realStore = 0;
  String _stringStore = '';

  Baseline2Benchmark() : super('Baseline2');

  @override
  void run() {
    switch (_counter++ % 2) {
      case 0:
        _realStore = 3.14;
        _integerStore = 42;
        _stringStore = 'hello';
      case 1:
        _realStore = -0.0;
        _integerStore = 1337;
        _stringStore = 'こんにちは世界';
      default:
        throw 'Unreachable';
    }
  }

  @override
  void teardown() {
    exitCode = _realStore.hashCode;
    exitCode = _integerStore;
    exitCode = _stringStore.hashCode;
  }
}

final class BaselineBenchmark extends _BaseBenchmark {
  int _store = 0;

  BaselineBenchmark() : super('Baseline');

  @override
  void run() {
    _store = getInt();
  }

  @override
  void teardown() {
    exitCode = _store;
  }
}

final class ClassBenchmark extends _BaseBenchmark {
  Clazz _store = Clazz(real: 0, integer: 0, string: '');

  ClassBenchmark() : super('Class');

  @override
  void run() {
    _store = getClass();
  }

  @override
  void teardown() {
    exitCode = _store.integer;
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
  Record _store = (real: 0, integer: 0, string: '');

  RecordBenchmark() : super('Record');

  @override
  void run() {
    _store = getRecord();
  }

  @override
  void teardown() {
    exitCode = _store.integer;
  }
}

sealed class _BaseBenchmark extends BenchmarkBase {
  int _counter = 0;

  _BaseBenchmark(super.name);

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
