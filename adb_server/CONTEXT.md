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

### Device Profile
A set of shell commands applied to the **DUT** before a **Trial** to ensure a stable and reproducible environment. This typically includes pinning CPU frequencies and setting the governor to `userspace` or `performance`.

### Thermal Gate
A mechanism that pauses the **Runner** before a **Trial** until the **DUT**'s SoC temperature falls below a configured threshold. This minimizes thermal throttling and ensures consistent performance across trials.

### Instrumentation
The Android system mechanism used to launch and monitor the benchmark trials. It requires a test package and an instrumentation runner.

### Runner
The process responsible for executing queued **Sessions**. Only one runner should be active at a time to prevent conflicts over the **DUT** and data directory. It uses a lock file to ensure mutual exclusion.

### Sentinel
A file-based signaling mechanism used by the app on the DUT to inform the `adb_server` that a trial has finished (`DONE`) or failed (`FAILED`). The server polls the device for these files.
