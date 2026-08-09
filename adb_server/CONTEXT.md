# Context: ADB Server

This document defines the domain terms used in the `adb_server` utility.

## Glossary

### Session
An execution-scoped container for a benchmarking run. A session is identified by a unique ID (e.g., `20260807__test1`) and contains the configuration (`session.json`), logs, and results for that specific execution. If an experiment needs to be repeated, a new session should be created.

### Round
A single cycle within a session where every defined **Variant** is executed exactly once. The order of variants within a round is typically randomized.

### Trial
A single execution of a specific **Variant** on the **DUT**. A trial is the smallest unit of measurement and produces raw data (e.g., logcat, frame timings).

### Variant
A specific build or configuration of the app being tested. For example, "baseline" might be the current production version, while "treatment" might be a version with a performance optimization.

### DUT (Device Under Test)
The Android device where the benchmark trials are executed. The `adb_server` communicates with the DUT via ADB (Android Debug Bridge).

### Instrumentation
The Android system mechanism used to launch and monitor the benchmark trials. It requires a test package and an instrumentation runner.

### Sentinel
A file-based signaling mechanism used by the app on the DUT to inform the `adb_server` that a trial has finished (`DONE`) or failed (`FAILED`). The server polls the device for these files.
