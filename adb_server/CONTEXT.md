# Context: ADB Server

This document defines the domain terms used in the `adb_server` utility.

## Glossary

### Session
An execution-scoped container for a benchmarking run. A session is identified by a unique ID (e.g., `20260807__test1`) and contains the configuration (`session.json`), logs, and results for that specific execution. If an experiment needs to be repeated, a new session should be created.

### Round
A single cycle within a session where every defined **Variant** is executed exactly once. The order of variants within a round is typically randomized.

### Trial
A single execution of a specific **Variant** on the **DUT**. A trial is the smallest unit of measurement and produces raw data (e.g., logcat, frame timings).

### Session Directory
The one directory on the NAS that *is* a **Session**: `sessions/<session_id>/`, where the directory name is the session ID. It is the only interface a submitter needs — dropping a directory in over SMB and calling `POST /api/sessions` converge on the same on-disk state — and it passes through four phases:

1. **Staged.** The submitter has written `session.json` and, flat beside it (never in subdirectories), the APK files every **Variant** names. There is no `status.json` yet. Producing a directory in this phase is the whole job of preparing an experiment; nothing in it belongs to the server.
2. **Discovered.** The server sees a directory holding `session.json` but no `status.json`, and writes one: `queued` if the spec parses, `invalid` — recording the parse error, never retried — if it does not.
3. **Filled.** The **Runner** appends, and only appends: `session.log`, plus one `trials/trial-NNN/` per **Trial** carrying its `trial.json`, its pulled result files and its logs. `status.json` is rewritten atomically as the state advances.
4. **Terminal.** `status.json` reaches `done`, `failed`, `cancelled` or `interrupted`. Partial artefacts stay on disk.

Through all four phases `session.json` is written once by the submitter and never modified by the server. Repeating an experiment means a new Session Directory, not a reset of this one.
_Avoid_: staging dir, job folder, submission

### Variant
A specific build or configuration of the app being tested. For example, "baseline" might be the current production version, while "treatment" might be a version with a performance optimization.

### DUT (Device Under Test)
The Android device where the benchmark trials are executed. The `adb_server` communicates with the DUT via ADB (Android Debug Bridge).

### Server Version
The specific version (Git commit hash) of the `adb_server` tool used to orchestrate a **Session**. It is recorded in every **Trial**'s metadata to ensure the infrastructure state is captured for auditability and reproducibility.

### Device Profile
A set of shell commands applied to the **DUT** before a **Trial** to ensure a stable and reproducible environment. This typically includes pinning CPU frequencies and setting the governor to `userspace` or `performance`. The `adb_server` automatically attempts to find and apply a profile matching the **DUT**'s model from its `profiles/` directory, unless overridden by configuration.

### Thermal Gate
A mechanism that pauses the **Runner** before a **Trial** until the **DUT**'s SoC temperature falls below a configured threshold. This minimizes thermal throttling and ensures consistent performance across trials.

### Instrumentation
The Android system mechanism used to launch and monitor the benchmark trials. It requires a test package and an instrumentation runner.

### Runner
The process responsible for executing queued **Sessions**. Only one runner should be active at a time to prevent conflicts over the **DUT** and data directory. It uses a lock file to ensure mutual exclusion.

### Sentinel
A file-based signaling mechanism used by the app on the DUT to inform the `adb_server` that a trial has finished (`DONE`) or failed (`FAILED`). The server polls the device for these files.
