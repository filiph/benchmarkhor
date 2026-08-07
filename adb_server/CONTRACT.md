# The `adb_server` ↔ benchmark APK contract

This is the contract a benchmark APK must honour so `adb_server` can reliably
detect when a run has finished, without parsing or interpreting the actual
measurement data.

The vocabulary here (Trial, Frame, Session) is defined in
[`doc/CONTEXT-SHARED.md`](../doc/CONTEXT-SHARED.md).

## Result files

The app writes all of its result files into the directory named in
`job.json`'s `device_result_dir`. Each file is a raw, self-contained
measurement stream, one record per line -- newline-delimited numbers for a
microbenchmark's Iterations, or newline-delimited JSON objects for a Trial's
Frames. The server pulls these files byte-for-byte and never parses,
transforms, sorts, rounds, or summarises their contents.

The app must not average, filter or bucket anything. A Frame that looks like
an outlier is still data; deciding that is the host's job.

For a worked example, see `example_apk/integration_test/frame_recorder.dart`,
which emits one JSON object per Frame with all six `FrameTiming` phase
timestamps and a phase tag.

## Completion signal

After every result file has been written, closed, and flushed, and only
then, the app creates a sentinel file named `DONE` in the same directory.

It also prints a single line to stdout/logcat:

```
BENCH_DONE <exit_code>
```

## Failure signal

On an unrecoverable error, the app writes a file named `FAILED` (instead of
`DONE`) into the result directory, with a short human-readable reason as its
contents, and/or prints:

```
BENCH_FAILED <reason>
```

## What the server does with this

In priority order, the server considers a run complete when:

1. `DONE` (or `FAILED`) exists in the result directory.
2. A `BENCH_DONE` / `BENCH_FAILED` marker is seen in the logcat stream.
3. The app's process has disappeared with no sentinel present, for two
   consecutive polls -- this is treated as a crash (`failed`), not success.
4. The configured `run_timeout_seconds` has elapsed -- treated as `failed`.

See `REQUIREMENTS.md` §6 for the full run lifecycle this fits into.
