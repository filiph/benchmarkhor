import 'dart:io';

import 'harness.dart';
import 'histogram_emitter.dart';

void main() {
  BaselineBenchmark().report();
  ClassBenchmark().report();
  RecordBenchmark().report();
  exitCode = 0;
  return;
}

typedef MyRecord = ({double real, int integer, String string});

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
  late final List<MyClass> _store =
      List.filled(count, MyClass(real: 0, integer: 0, string: ''));

  ClassBenchmark() : super('MyClass');

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

final class MyClass {
  final double real;
  final int integer;
  final String string;

  const MyClass(
      {required this.real, required this.integer, required this.string});
}

final class RecordBenchmark extends _BaseBenchmark {
  late final List<MyRecord> _store =
      List.filled(count, (real: 0, integer: 0, string: ''));

  RecordBenchmark() : super('MyRecord');

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

  _BaseBenchmark(super.name) : super(emitter: HistogramEmitter());

  @override
  void exercise() => run();

  MyClass getClass() => switch (_counter++ % 2) {
        0 => MyClass(real: 3.14, integer: 42, string: "hello"),
        1 => MyClass(real: -0.0, integer: 1337, string: "こんにちは世界"),
        _ => throw 'Unreachable',
      };

  int getInt() => switch (_counter++ % 2) {
        0 => 1,
        1 => 2,
        _ => throw 'Unreachable',
      };

  MyRecord getRecord() => switch (_counter++ % 2) {
        0 => (real: 3.14, integer: 42, string: "hello"),
        1 => (real: -0.0, integer: 1337, string: "こんにちは世界"),
        _ => throw 'Unreachable',
      };
}
