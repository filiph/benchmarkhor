import 'dart:io';

import 'package:benchmarkhor/benchmark_recorder.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On Android, adb_server expects results in the application files directory.
  const package = 'com.example.dart_benchmark_harness';
  final resultDir = Platform.isAndroid
      ? BenchmarkRecorder.defaultDeviceResultDir(package)
      : Directory.current;

  final recorder = BenchmarkRecorder(outputDir: resultDir);

  // Run the benchmark in the background while displaying a minimal UI.
  runApp(const BenchmarkHarnessApp());

  try {
    debugPrint('Harness: starting benchmark workload...');

    // Warmup iterations (unmeasured)
    for (var i = 0; i < 5; i++) {
      benchmarkWorkload();
    }

    // Measured iterations
    const iterations = 50;
    for (var i = 0; i < iterations; i++) {
      recorder.measure(() {
        benchmarkWorkload();
      });
    }

    debugPrint('Harness: completed $iterations iterations. Writing DONE sentinel.');
    await recorder.complete();
  } catch (e, stack) {
    debugPrint('Harness: error executing benchmark: $e\n$stack');
    await recorder.fail(e.toString());
  }
}

/// The pure-Dart workload to measure. Replace this with your benchmark target.
void benchmarkWorkload() {
  final list = List.generate(10000, (i) => 10000 - i);
  list.sort();
}

/// Minimal visual harness to satisfy Android Activity requirements.
class BenchmarkHarnessApp extends StatelessWidget {
  const BenchmarkHarnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Running pure-Dart benchmark...',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
