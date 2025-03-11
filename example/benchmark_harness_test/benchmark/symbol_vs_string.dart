import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';

void main() {
  final baseline = BaselineBenchmark().measure();
  final symbol = SymbolBenchmark().measure();
  final string = StringBenchmark().measure();

  print('String:\t${string / baseline}x\t${string - baseline}');
  print('Symbol:\t${symbol / baseline}x\t${symbol - baseline}');

  print('---');
  print('Symbol is: ${((symbol / string - 1) * 100).round()}% slower.');
  print('Symbol overhead is: '
      '${(((symbol - baseline) / (string - baseline) - 1) * 100).round()}% '
      'slower.');

  BaselineBenchmark().report();
  StringBenchmark().report();
  SymbolBenchmark().report();
  exitCode = 0;
  return;
}

typedef MyRecord = ({double real, int integer, String string});

final class BaselineBenchmark extends _BaseBenchmark<int> {
  MyClass? _latest;

  @override
  late final Map<int, MyClass> store = {
    1: MyClass(real: 0, integer: 0, string: ''),
    2: MyClass(real: 0, integer: 0, string: ''),
    3: MyClass(real: 0, integer: 0, string: ''),
    4: MyClass(real: 0, integer: 0, string: ''),
    5: MyClass(real: 0, integer: 0, string: ''),
    6: MyClass(real: 0, integer: 0, string: ''),
    7: MyClass(real: 3.14, integer: 42, string: 'exception'),
    8: MyClass(real: 0, integer: 0, string: ''),
    9: MyClass(real: 0, integer: 0, string: ''),
    10: MyClass(real: 0, integer: 0, string: ''),
    11: MyClass(real: 0, integer: 0, string: ''),
    12: MyClass(real: 0, integer: 0, string: ''),
    13: MyClass(real: 0, integer: 0, string: ''),
    14: MyClass(real: 0, integer: 0, string: ''),
    15: MyClass(real: 0, integer: 0, string: ''),
    16: MyClass(real: 0, integer: 0, string: ''),
    17: MyClass(real: 0, integer: 0, string: ''),
  };

  BaselineBenchmark() : super('Baseline');

  @override
  void run() {
    for (var i = 0; i < count; i++) {
      final key = i % 3 == 0 ? 16 : 7;
      _latest = getVia(key);
    }
  }

  @override
  void teardown() {
    exitCode = _latest?.integer ?? 100;
  }
}

final class StringBenchmark extends _BaseBenchmark<String> {
  MyClass? _latest;

  @override
  late final Map<String, MyClass> store = {
    'hello1': MyClass(real: 0, integer: 0, string: ''),
    'hello2': MyClass(real: 0, integer: 0, string: ''),
    'hello3': MyClass(real: 0, integer: 0, string: ''),
    'hello4': MyClass(real: 0, integer: 0, string: ''),
    'hello5': MyClass(real: 0, integer: 0, string: ''),
    'hello6': MyClass(real: 0, integer: 0, string: ''),
    'hello7': MyClass(real: 3.14, integer: 42, string: 'exception'),
    'hello8': MyClass(real: 0, integer: 0, string: ''),
    'hello9': MyClass(real: 0, integer: 0, string: ''),
    'hello10': MyClass(real: 0, integer: 0, string: ''),
    'hello11': MyClass(real: 0, integer: 0, string: ''),
    'hello12': MyClass(real: 0, integer: 0, string: ''),
    'hello13': MyClass(real: 0, integer: 0, string: ''),
    'hello14': MyClass(real: 0, integer: 0, string: ''),
    'hello15': MyClass(real: 0, integer: 0, string: ''),
    'hello16': MyClass(real: 0, integer: 0, string: ''),
    'hello17': MyClass(real: 0, integer: 0, string: ''),
  };

  StringBenchmark() : super('String');

  @override
  void run() {
    for (var i = 0; i < count; i++) {
      final key = i % 3 == 0 ? 'hello16' : 'hello7';
      _latest = getVia(key);
    }
  }

  @override
  void teardown() {
    exitCode = _latest?.integer ?? 100;
  }
}

final class MyClass {
  final double real;
  final int integer;
  final String string;

  const MyClass(
      {required this.real, required this.integer, required this.string});
}

final class SymbolBenchmark extends _BaseBenchmark<Symbol> {
  MyClass? _latest;

  @override
  late final Map<Symbol, MyClass> store = {
    #hello1: MyClass(real: 0, integer: 0, string: ''),
    #hello2: MyClass(real: 0, integer: 0, string: ''),
    #hello3: MyClass(real: 0, integer: 0, string: ''),
    #hello4: MyClass(real: 0, integer: 0, string: ''),
    #hello5: MyClass(real: 0, integer: 0, string: ''),
    #hello6: MyClass(real: 0, integer: 0, string: ''),
    #hello7: MyClass(real: 3.14, integer: 42, string: 'exception'),
    #hello8: MyClass(real: 0, integer: 0, string: ''),
    #hello9: MyClass(real: 0, integer: 0, string: ''),
    #hello10: MyClass(real: 0, integer: 0, string: ''),
    #hello11: MyClass(real: 0, integer: 0, string: ''),
    #hello12: MyClass(real: 0, integer: 0, string: ''),
    #hello13: MyClass(real: 0, integer: 0, string: ''),
    #hello14: MyClass(real: 0, integer: 0, string: ''),
    #hello15: MyClass(real: 0, integer: 0, string: ''),
    #hello16: MyClass(real: 0, integer: 0, string: ''),
    #hello17: MyClass(real: 0, integer: 0, string: ''),
  };

  SymbolBenchmark() : super('Symbol');

  @override
  void run() {
    for (var i = 0; i < count; i++) {
      final key = i % 3 == 0 ? #hello16 : #hello7;
      _latest = getVia(key);
    }
  }

  @override
  void teardown() {
    exitCode = _latest?.integer ?? 100;
  }
}

sealed class _BaseBenchmark<T> extends BenchmarkBase {
  Map<T, MyClass> get store;

  final int count = 1000;

  _BaseBenchmark(super.name);

  @override
  void exercise() => run();

  MyClass getVia(T key) => store[key]!;
}
