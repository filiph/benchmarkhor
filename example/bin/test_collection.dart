import 'dart:io';
import 'dart:typed_data';

const int iterations = 10000;

void main(List<String> args) {
  final n = int.parse(args[0]);

  const variant = String.fromEnvironment('variant');
  switch (variant) {
    case 'typed':
      runTyped(n);
    case 'basic':
      runBasic(n);
    default:
      stderr.writeln("Must provide variant to run during compilation.");
      exit(1);
  }
}

/// A trick from C++ benchmark libraries to prevent the compiler from
/// optimizing away an unused value.
@pragma('vm:never-inline')
void doNotOptimizeAway(int value) {
  // This will never be true but the compiler can't prove it.
  if (DateTime.timestamp().millisecondsSinceEpoch == 0) {
    print(value);
  }
}

void runBasic(int n) {
  final collection = List<int>.generate(n, (index) => index,
      growable: bool.fromEnvironment('fake', defaultValue: false));

  final stopwatch = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    _forLoopBasic(collection);
  }
  stopwatch.stop();

  print('List.generate(): ${stopwatch.elapsedMicroseconds}us');
}

void runTyped(int n) {
  final collection = Int64List(n);
  for (int i = 0; i < n; i++) {
    collection[i] = i;
  }

  final stopwatch = Stopwatch()..start();
  for (int i = 0; i < iterations; i++) {
    _forLoopTyped(collection);
  }
  stopwatch.stop();

  print('TypedData: ${stopwatch.elapsedMicroseconds}us');
}

@pragma('vm:never-inline')
void _forLoopBasic(List<int> collection) {
  var result = 0;
  for (int i = 0; i < collection.length; i++) {
    result += collection[i];
  }
  doNotOptimizeAway(result);
}

@pragma('vm:never-inline')
void _forLoopTyped(Int64List collection) {
  var result = 0;
  for (int i = 0; i < collection.length; i++) {
    result += collection[i];
  }
  doNotOptimizeAway(result);
}
