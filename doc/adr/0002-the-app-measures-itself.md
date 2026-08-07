# The app measures itself

Benchmark APKs are launched with `adb shell am instrument` against an APK pair,
and the app records its own **Frames** via `SchedulerBinding.addTimingsCallback`,
writing one JSON object per Frame to a file on the device. We rejected Flutter's
documented profiling recipe — `binding.traceAction()` plus a `perf_driver.dart`
host script — even though it is what the official cookbook prescribes and what
`lib/extract.dart` currently parses.

The chain is a single argument. `am instrument` is the only launch mechanism that
lets an unattended NAS drive an unattended Orange Pi over `adb` with no Flutter
SDK, no VM-service tunnel and no host process babysitting the run. But no host
process means no `traceAction`, which works by driving the VM service from the
other end of a `flutter drive` connection. So the measurement has to live inside
the app, which in turn means the artifact is whatever the app can write to disk:
newline-delimited JSON, one record per Frame, with all six `FrameTiming` phase
timestamps and a phase tag. Per-Frame rows rather than bare numbers because
dropped frames and thermal drift are only visible if timestamps survive.

## Consequences

`lib/extract.dart` no longer describes how data arrives. It reads Chrome-trace
timeline JSON, which nothing in the new path produces, so a second ingestion path
for the per-Frame JSONL is now owed before any of this data can be plotted.

The device is dumb by contract: it never averages, filters or sorts, and
`adb_server` never parses what it pulls. Every analytical decision therefore has
to be made on the host, from raw Frames, forever.

`flutter drive` and `test_driver/integration_test.dart` survive only as a local
dev loop. The driver script carries no profiling logic, and running it locally
requires `--keep-app-running`, because uninstalling the app wipes
`/sdcard/Android/data/<pkg>/` along with the results.

Instrumentation cannot run against a `--release` build, so **profile** is the
most realistic build this rig will ever measure. Release-mode numbers are out of
reach by construction.
