# Pure-Dart benchmarks run via Harness APK

Pure-Dart benchmarks evaluate algorithmic and CPU-bound Dart code on physical
Android Devices Under Test (DUTs) under the same thermal and environmental controls
as Flutter application benchmarks. Standalone native ELF binaries cannot be built
with `dart compile exe` for Android because the Dart SDK only targets GNU/Linux
glibc on ARM64 (`linux_arm64`) and rejects Android Bionic targets. Compiling
standalone executables would require non-standard NDK toolchains or custom Dart VM
embeddings that diverge from the runtime used in production.

Instead, pure-Dart benchmarks are wrapped inside a minimal Flutter application
(**Harness APK**). This leverages Flutter's battle-tested AOT Dart runtime on
Android with zero custom NDK tooling.

Rather than requiring an empty companion test APK launched via `am instrument`,
`adb_server` is extended to support single-APK variants launched directly via
`am start -n <package>/<launch_activity>`. The harness executes user-supplied
Dart benchmark code in its `main()` entrypoint.

Conforming to ADR 0002 ("The app measures itself"), the device remains dumb:
it records raw unaggregated iteration durations to `iterations.jsonl` and writes a
`DONE` or `FAILED` sentinel file upon completion. Analytical aggregation (mean,
median, percentiles, bootstrap comparisons) is performed strictly on the host by
`bin/extract_dat.dart`.

## Consequences

`adb_server` gains first-class support for single-APK variants where `test_apk`
is omitted in `session.json`. In this mode, `adb_server` skips test APK
installation, launches the configured activity via `am start`, and monitors
logcat, process lifecycle via `pidof`, and completion sentinels.

`bin/extract_dat.dart` detects `iterations.jsonl` when `frames.jsonl` is absent,
aggregating iteration timings into `.dat` metric files compatible with
`bin/plot.dart` and computing bootstrap effect-size comparisons.

Benchmark authors retain control over warmup iterations, batching, and measurement
passes through a self-driven loop using a lightweight `BenchmarkRecorder` helper.
Because the workload runs within an Android Activity process, benchmarks must be
aware of Android execution constraints and lifecycle timeouts.
