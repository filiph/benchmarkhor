import 'dart:io';

import 'package:benchmarkhor/benchmark_recorder.dart';
import 'package:flutter/material.dart';

final statusNotifier = ValueNotifier<String>('Initializing...');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On Android, adb_server expects results in the application files directory.
  const package = 'com.example.dart_benchmark_harness';
  final resultDir = Platform.isAndroid
      ? BenchmarkRecorder.defaultDeviceResultDir(package)
      : Directory.current;

  // Run the benchmark while displaying a minimal UI.
  runApp(const BenchmarkHarnessApp());

  // Allow Flutter to render the first frame before entering CPU-intensive loops.
  await WidgetsBinding.instance.endOfFrame;

  Future<void> updateStatus(String status) async {
    statusNotifier.value = status;
    // Yield to the event loop and allow Flutter's engine to render the frame.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  BenchmarkRecorder? recorder;
  try {
    debugPrint('Harness: starting benchmark workload...');
    await updateStatus('Setting up recorder...');
    recorder = BenchmarkRecorder(outputDir: resultDir);

    // Warmup iterations (unmeasured)
    await updateStatus('Running warmup iterations...');
    for (var i = 0; i < 5; i++) {
      benchmarkWorkload();
      await Future<void>.delayed(Duration.zero);
    }

    // Measured iterations (never update UI inside the measured loop!)
    const iterations = 50;
    await updateStatus('Measuring $iterations iterations...');
    for (var i = 0; i < iterations; i++) {
      recorder.measure(() {
        benchmarkWorkload();
      });
      // Yield to the event loop so Android's main looper processes window focus,
      // input events, and lifecycle messages, preventing ANR (5,000ms timeout).
      await Future<void>.delayed(Duration.zero);
    }

    await updateStatus('Completed. Writing DONE sentinel...');
    debugPrint('Harness: completed $iterations iterations. Writing DONE sentinel.');
    await recorder.complete();
    await updateStatus('Done.');
  } catch (e, stack) {
    debugPrint('Harness: error executing benchmark: $e\n$stack');
    // Printed to logcat on Android first so adb_server detects failure immediately
    // ignore: avoid_print
    print('BENCH_FAILED $e');
    statusNotifier.value = 'Failed: $e';
    if (recorder != null) {
      await recorder.fail(e.toString());
    } else {
      try {
        final failedFile = File('${resultDir.path}/FAILED');
        await failedFile.writeAsString(e.toString());
      } catch (_) {}
    }
  }
}

/// The pure-Dart workload to measure. Replace this with your benchmark target.
void benchmarkWorkload() {
  final list = List.generate(10000, (i) => 10000 - i);
  list.sort();
}

/// Minimal visual harness displaying phase progress to satisfy Android Activity requirements.
class BenchmarkHarnessApp extends StatelessWidget {
  const BenchmarkHarnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder<String>(
            valueListenable: statusNotifier,
            builder: (context, status, _) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Pure-Dart Benchmark Harness',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      status,
                      style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
