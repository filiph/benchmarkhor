# Dart Benchmark Harness

A minimal Flutter application that serves as the canonical reference Harness APK for running pure-Dart (non-UI) benchmarks on Android DUTs (Devices Under Test) using Benchmarkhor.

## What is this?

Benchmarkhor benchmarks performance on real Android hardware via `adb_server`. While Flutter UI benchmarks record frame rendering timings (`frames.jsonl`) via an APK pair launched by `am instrument`, pure-Dart benchmarks measure raw algorithmic / CPU execution times (`iterations.jsonl`).

Because the Dart SDK cannot compile standalone Android ELF executables directly (`dart compile exe` targets GNU/Linux glibc rather than Android Bionic), this harness wraps pure-Dart workloads inside a headless Flutter Activity. Flutter provides the production-grade, AOT-compiled Dart runtime on Android.

Key characteristics:
- **Single APK**: Launched directly via `am start -n <package>/<activity>` (no test APK or bridge required).
- **Self-driven loop**: Your Dart code controls warmup iterations, measurement passes, and error handling.
- **Raw iteration records**: Emits unaggregated execution durations in microseconds to `iterations.jsonl`.
- **Completion sentinels**: Emits a `DONE` or `FAILED` file in the device results directory and logcat markers (`BENCH_DONE` / `BENCH_FAILED`).

## Project Structure

- `lib/main.dart`: Benchmark entry point. Initializes Flutter, instantiates `BenchmarkRecorder`, runs warmup and measured iterations, and signals completion.
- `android/`: Minimal Android scaffolding with `MainActivity` configured to run the Dart workload.

## How It Works

1. `main()` initializes the Flutter binding and starts a minimal visual widget (`BenchmarkHarnessApp`) to satisfy Android Activity lifecycle constraints.
2. A `BenchmarkRecorder` is configured to write to the application's external files directory:
   `/sdcard/Android/data/com.example.dart_benchmark_harness/files`
3. Unmeasured warmup iterations run to stabilize CPU frequencies and JIT/AOT caches.
4. Measured iterations are recorded using `recorder.measure(() => benchmarkWorkload())`. Each iteration appends a JSON line:
   ```json
   {"iteration": 1, "durationUs": 1420, "timestampUs": 1711200000000}
   ```
5. On completion, `recorder.complete()` closes the file and writes the `DONE` sentinel file. If an exception occurs, `recorder.fail()` writes the `FAILED` sentinel.

## Customizing for Your Benchmark

1. Open `lib/main.dart`.
2. Replace `benchmarkWorkload()` with your target function, data structure, or algorithm:
   ```dart
   void benchmarkWorkload() {
     // Your CPU/algorithmic benchmark workload here
   }
   ```
3. Adjust warmup and iteration counts to suit the granularity of your workload:
   - For sub-millisecond workloads: batch multiple operations per iteration or run 50–100 iterations.
   - For long-running workloads: run fewer iterations.

## Building for Benchmarkhor

Each Variant is built as a single profile APK. Run:

```sh
flutter clean
flutter build apk --profile --target-platform android-arm64
```

The output APK is located at:
`build/app/outputs/flutter-apk/app-profile.apk`

Copy this APK into your Benchmarkhor session directory (e.g. `baseline.apk`, `optimized.apk`).

## Session Configuration (`session.json`)

Reference the harness in your `session.json` by specifying `launch_activity` and `expected_result_files`:

```json
{
  "schema_version": 1,
  "name": "my-dart-benchmark",
  "package": "com.example.dart_benchmark_harness",
  "launch_activity": "com.example.dart_benchmark_harness.MainActivity",
  "device_result_dir": "/sdcard/Android/data/com.example.dart_benchmark_harness/files",
  "rounds": 30,
  "expected_result_files": ["iterations.jsonl"],
  "variants": {
    "baseline": {
      "apk": "baseline.apk",
      "source": "git commit-or-ref"
    },
    "optimized": {
      "apk": "optimized.apk",
      "source": "git commit-or-ref"
    }
  }
}
```
