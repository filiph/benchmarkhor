# `adb_server` -- Requirements & Design Brief

**Audience:** an LLM coding agent implementing v1 from scratch.
**Status:** greenfield. Nothing exists yet in `adb_server/`.
**Instruction to the agent:** read this whole document before writing code. Ask the user questions when something is underspecified -- a list of known open questions is at the end, but don't treat it as exhaustive. Prefer asking over guessing.

---

## 1. What this is

A small, long-running **Dart server in a Docker container** that lives on a Synology NAS and acts as the control plane for a Flutter performance-benchmarking rig.

It does four things:

1. Exposes a REST-ish HTTP API (and a minimal HTML status page) over the LAN.
2. Keeps **all state on disk** as plain files on a NAS volume.
3. Drives an Android device over **ADB via TCP/IP** (no USB) to install and run benchmark APKs.
4. Collects raw result files plus as much environmental metadata as it can, and stores them on the NAS.

### The physical rig

| Component | Role | Notes |
|---|---|---|
| Synology NAS, Intel Celeron J4125 | Runs this container | **x86_64 / amd64** -- build for amd64 |
| Orange Pi 5B (Rockchip RK3588S, Android 12) | Device under test ("DUT") | On the same LAN, wired Ethernet, mains-powered, headless-ish (HDMI dummy plug) |
| Flutter benchmark APKs | The actual experiments | An **APK pair** -- app + `androidTest` -- launched with `am instrument`. Profile builds (`--release` is not available to instrumentation). The app writes its own results to files on-device |

The NAS and the DUT talk only over Ethernet. There is no human present during runs.

### The measurement context (why the design is shaped this way)

The primary use case in v1 is **R&D microbenchmarking of Dart code** -- e.g. "is `Set<Enum>.contains()` faster than `Set<SomeObject>.contains()`?" -- where:

- Expected effect sizes are **large (10%+)**. We are not chasing 1% effects yet.
- The DUT's CPU is **deliberately downclocked and pinned** so thermal drift is small.
- Each benchmark runs **many iterations**, and the **APK itself is responsible for interleaving** variants (A/B/A/B/...). The server never interleaves anything.
- **The output is thousands of raw data points, not summary statistics.** This is a hard requirement, see §6.

A secondary future use case is frame-timing benchmarks. Don't build for it, but don't design anything that forbids it.

---

## 2. Non-goals for v1

Be disciplined about these. "Crawl, walk, run" -- this is crawl.

- ❌ No authentication, no TLS, no multi-user support. Trusted LAN only.
- ❌ No database. No Postgres, no Redis, no SQLite. The filesystem is the database.
- ❌ **No statistical analysis, aggregation, mean/stddev computation, or plotting.** The server is a faithful courier of raw data.
- ❌ No automatic queue draining in v1 -- a run starts only when explicitly asked via the API (see §5).
- ❌ No CI integration, no webhooks, no notifications.
- ❌ No multi-device support. Exactly one DUT, configured by env var. Design the ADB layer so a second device could be added later, but don't implement it.
- ❌ No building of APKs. APKs arrive prebuilt.
- ❌ No Ansible, no systemd, no shell-script orchestration layer. Everything is Dart calling `adb` as a subprocess.
- ❌ No fancy frontend framework. See §8.

---

## 3. Tech stack

| Concern | Choice |
|---|---|
| Language | Dart, latest stable SDK -- currently **3.12.x** |
| HTTP server | `shelf` + `shelf_router` (currently **1.1.4**) + `shelf_static` |
| Routing style | `Router()` with `app.get('/path/<param>', handler)` |
| Other packages | `args`, `crypto` (sha256), `path`, `logging`. Add more only with justification. |
| Container base | Official `dart` image, multi-stage → AOT-compiled binary in a slim runtime stage |
| ADB | Pinned Android platform-tools, **not** distro `apt install adb` (version drift) |

Rationale for Dart over Python/Bash: the user is a Flutter developer and intends to publish this methodology to the Flutter community. A Dart implementation is the shareable one. Also, the server process is the *only* orchestration layer -- there is no separate runner process, cron job, or shell wrapper.

---

## 4. On-disk layout (the source of truth)

Everything lives under a single configurable root, bind-mounted from the NAS. Proposed default `/data`.

```
/data/
  jobs/
    2026-08-03T14-22-05Z__set-contains-enum-vs-object/
      job.json            # immutable job spec (written by submitter)
      app.apk             # the benchmark APK
      app-test.apk        # its androidTest APK (same signing key as app.apk)
      status.json         # MUTABLE server-owned state
      job.log             # human-readable log for this job
      runs/
        run-001/
          run.json        # full metadata snapshot for this single execution
          logcat.txt      # filtered logcat captured during the run
          adb.log         # every adb command + exit code + stderr
          results/        # verbatim files pulled off the device
            baseline.txt
            variant_a.txt
            variant_b.txt
          results_index.json   # filename, bytes, sha256, line count -- nothing more
  archive/                # completed jobs moved here (optional, v1 may skip)
  device/
    last_snapshot.json    # most recent device probe, for GET /api/device
  server.log
```

### Rules

- **Job ID = directory name.** Use `<ISO8601-utc-compact>__<slug>`. This makes lexicographic sort = chronological sort, which is also the queue order (FIFO).
- **`job.json` is written once and never modified by the server.** All mutable state goes in `status.json`.
- **All writes to `status.json` and `run.json` must be atomic**: write to `foo.json.tmp` in the same directory, `flush()`, then `rename()`. Never leave a half-written status file -- a crash mid-write must not corrupt the queue.
- **Nothing important is held only in memory.** If the container is killed (DSM update, power loss), restarting it must recover the full picture from disk.
- The user can and will interact with these directories directly over SMB. Filenames must be human-readable and SMB-safe: no `:` (breaks on some clients -- hence `14-22-05` not `14:22:05`), no characters needing escaping.

### `job.json` (submitter-authored)

Design a minimal schema, roughly:

```json
{
  "schema_version": 1,
  "name": "set-contains-enum-vs-object",
  "description": "Free text. Shown in the UI.",
  "apk": "app.apk",
  "test_apk": "app-test.apk",
  "package": "com.example.benchmark",
  "test_package": "com.example.benchmark.test",
  "instrumentation_runner": "dev.flutter.plugins.integration_test.FlutterTestRunner",
  "repetitions": 3,
  "run_timeout_seconds": 1800,
  "expected_result_files": ["baseline.txt", "variant_a.txt", "variant_b.txt"],
  "device_result_dir": "/sdcard/Android/data/com.example.benchmark/files/bench",
  "tags": { "flutter": "3.41", "git_commit": "abc123", "notes": "..." }
}
```

`repetitions` = how many times the server executes the whole APK (each producing one `runs/run-NNN/`). Note this is *sessions*, not iterations -- iteration count and interleaving are the APK's business.

Validate the schema on read. A malformed `job.json` must move the job to state `invalid` **immediately, with the parse error recorded in `status.json`** -- never retried in a loop. (This is a specific bug to avoid: a poll loop that skips a bad job without marking it will spin forever.)

### `status.json` (server-owned)

```json
{
  "schema_version": 1,
  "job_id": "...",
  "state": "queued",
  "created_at": "...",
  "updated_at": "...",
  "runs_completed": 0,
  "runs_planned": 3,
  "current_run": null,
  "history": [ { "at": "...", "from": "queued", "to": "running", "reason": "..." } ],
  "error": null
}
```

### Job state machine

```
queued ──▶ running ──▶ done
   │          │
   │          ├──▶ failed       (adb error, timeout, missing results)
   │          ├──▶ cancelled    (explicit cancel while running)
   │          └──▶ interrupted  (server restarted mid-run)
   ├──▶ cancelled  (explicit cancel while queued)
   └──▶ invalid    (bad job.json / missing APK)
```

**On startup**, scan `jobs/`. Any job found in `running` is stale by definition -- transition it to `interrupted` with a reason. Do not attempt to resume it. Partial artifacts stay on disk.

---

## 5. HTTP API

Bind `0.0.0.0` on a configurable port (default `8080`). All JSON responses, `application/json`, with a top-level object (never a bare array -- leaves room for pagination later).

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Liveness. Returns version, uptime, `busy: bool`, config summary. |
| `GET` | `/api/jobs` | List jobs. Optional `?state=queued`. Returns summaries, newest first. |
| `GET` | `/api/jobs/<id>` | Full detail: merged `job.json` + `status.json` + list of runs. |
| `POST` | `/api/jobs` | Create a job. See below. |
| `POST` | `/api/jobs/<id>/cancel` | Cancel queued or running job. |
| `POST` | `/api/queue/next` | **Start the next queued job if idle.** Core operation. |
| `GET` | `/api/device` | Probe the DUT now and return a metadata snapshot (§7). Cache briefly. |
| `GET` | `/api/jobs/<id>/runs/<run>/results/<file>` | Serve a raw result file (`text/plain`). |
| `GET` | `/api/jobs/<id>/log` | Tail of `job.log`, `?lines=N`. |
| `GET` | `/` | Minimal HTML status page (§8). |

### `POST /api/queue/next` semantics -- read carefully

- If a run is already in progress: return **409 Conflict** with the current job ID. Do not queue the request, do not block.
- If no jobs are `queued`: return **204 No Content** (or 200 with `{"started": null}` -- agent's choice, document it).
- Otherwise: pick the **lexicographically first** `queued` job, transition it to `running`, kick off execution **asynchronously**, and return **202 Accepted** with the job ID immediately. Do not hold the HTTP connection open for the duration of a 30-minute benchmark.

Mutual exclusion must be enforced by **two** mechanisms:
1. An in-process guard (a single `bool`/`Completer` behind synchronous check-and-set -- no `await` between check and set).
2. A lock file on disk (`/data/.runner.lock` containing pid + job ID + timestamp) so a second accidentally-started container fails loudly instead of two adb clients fighting over one device. **Two ADB clients targeting one device concurrently is a known source of mystery flakiness -- prevent it structurally.**

### `POST /api/jobs`

Support `multipart/form-data` with an `apk` file part and a `job` JSON part. Create the directory, write `job.json` + `app.apk`, compute the APK sha256, set state `queued`, return 201 with the job ID.

Also support the **drop-folder path**: the user copies a directory into `/data/jobs/` over SMB. So the job lister must treat "directory containing `job.json` but no `status.json`" as a newly discovered job and create `status.json` with state `queued` on first sight. Both submission paths must converge on identical on-disk state.

### `POST /api/jobs/<id>/cancel`

- `queued` → `cancelled`, done.
- `running` → set a cancellation flag the run loop checks between steps, `adb shell am force-stop <pkg>`, mark `cancelled`, **keep partial artifacts**. Return 202.
- Any terminal state → 409.

---

## 6. The run lifecycle

This is the heart of the program. Implement it as an explicit, ordered, logged sequence. Every adb invocation and its exit code/stderr goes into `runs/run-NNN/adb.log`.

For each of `repetitions`:

1. **Create** `runs/run-NNN/` (zero-padded, starting at 001).
2. **Connect / verify device.** `adb connect <addr>`, then `adb -s <addr> get-state`. Retry a small number of times with backoff. If the device reports `unauthorized`, fail with a clear, actionable error message (see §10 -- this is the most likely first-time failure).
3. **Apply the device profile** (optional, config-driven). If a profile script/command list is configured, run it and record the commands verbatim + their sha256 in `run.json`. This is how the user pins CPU governor, frequency, and core affinity for downclocked stable operation. The server does not invent these commands -- it executes what it's given and records what it did.
4. **Pre-run device snapshot** → `run.json` under `device_before` (§7).
5. **Optional thermal gate.** If configured, poll SoC temperature until below a threshold or a timeout expires. In v1, on timeout: proceed but record a `warnings: ["thermal_gate_timeout"]` entry. Do not silently drop the run.
6. **Clean device state.** Remove the on-device result directory. Uninstall both the package and the test package if present (avoids stale files and stale caches masquerading as results). Note that uninstalling wipes `/sdcard/Android/data/<pkg>/`, so this must happen *before* the install, never after the pull.
7. **Install:** `adb install -r -g app.apk`, then `adb install -r -g app-test.apk`. Both must be signed with the same key or `am instrument` fails obscurely.
8. **Optional AOT settle:** `adb shell cmd package compile -m speed -f <pkg>`, then a short idle wait. Configurable, default on. Rationale: `install` triggers background dexopt that can churn for minutes and contaminate an early run.
9. **Keep the device awake:** `adb shell svc power stayon true` and add the package to the deviceidle whitelist. Log failures as warnings, not errors -- these commands vary across builds.
10. **Clear logcat** (`adb logcat -c`), then start capturing logcat to `logcat.txt` for the duration of the run.
11. **Launch:** `adb shell am instrument -w -r <test_package>/<instrumentation_runner>` (plus any extras from `job.json`).
    Do not trust `am instrument -w` to return: a known Flutter regression leaves instrumentation hanging after "All tests passed!", so wrap every invocation in a host-side timeout and treat the completion contract below -- not the exit status -- as the signal.
    Parameterise by `adb push`ing a scenario file into `device_result_dir` rather than fighting `-e` extras into Dart.
12. **Wait for completion** -- see the contract below.
13. **Post-run device snapshot** → `device_after`.
14. **Pull results:** copy every file from the on-device result dir into `runs/run-NNN/results/`. Then write `results_index.json` with filename, byte size, sha256, and line count per file. **Do not parse, transform, sort, round, or summarise the contents.** They are raw measurement streams and must survive byte-identical.
15. **Validate:** if `expected_result_files` is set and any are missing or zero-length → run `failed`.
16. **Finalise:** write `run.json`, `am force-stop`, increment `runs_completed`, update `status.json` atomically.

After the last repetition → job `done`. If any repetition fails, v1 behaviour: **abort remaining repetitions**, job `failed`, keep everything collected so far. (Ask the user if they'd prefer continue-on-error.)

### Completion contract between server and APK

This is a **published contract** the user's benchmark APKs must honour. Documented in `adb_server/CONTRACT.md`:

> The app writes all result files into its result directory, then -- **last, after every other file is closed and flushed** -- creates a sentinel file named `DONE`. It also prints a single line to stdout/logcat: `BENCH_DONE <exit_code>`. On unrecoverable error it writes `FAILED` instead, with a reason as its contents.

Server-side detection, in priority order:
1. Sentinel file exists (`adb shell test -f <dir>/DONE`).
2. `BENCH_DONE` / `BENCH_FAILED` marker seen in the logcat stream.
3. Process gone (`adb shell pidof <pkg>` returns nothing) **for two consecutive polls** -- treat a vanished process with no sentinel as a **crash**, i.e. `failed`, not success. Capture logcat for diagnosis.
4. `run_timeout_seconds` exceeded → `failed`, force-stop, still pull whatever exists.

**Polling interval:** configurable, default **15 seconds**. Each poll wakes adbd, forks a process on the DUT, and generates network traffic. For the CPU-bound R&D benchmarks targeted here (10%+ effects, downclocked CPU) that noise is negligible. For future frame-timing work it may not be, so the interval must be tunable and its value must be recorded in `run.json`.

---

## 7. Metadata collection

The philosophy: **the benchmark APK owns the measurement; the server owns the provenance.** Capture aggressively -- storage is free and a result without context is worthless in three months.

Every field is best-effort: a missing/unsupported command records `null` plus a note in `warnings`, and **never** fails the run. Rockchip's Android 12 BSP is not an OEM build and some commands will be absent or no-ops.

### Per-run, before and after

| Field | Source (verify each on the actual device) |
|---|---|
| SoC temperatures | `cat /sys/class/thermal/thermal_zone*/temp` + matching `.../type` for labels |
| Per-core current frequency | `/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq` |
| Governor, min/max freq | `.../scaling_governor`, `scaling_min_freq`, `scaling_max_freq` |
| Online cores | `/sys/devices/system/cpu/online` |
| Thermal service state | `dumpsys thermalservice` (may be absent) |
| Free/total memory | `cat /proc/meminfo` |
| Uptime, load | `cat /proc/uptime`, `/proc/loadavg` |
| Wall clock skew | device `date` vs server time |

### Per-run, once

| Field | Source |
|---|---|
| Build fingerprint, Android version, ABI list | `getprop ro.build.fingerprint`, `ro.build.version.release`, `ro.product.cpu.abilist` |
| Device model / board / hardware | `getprop ro.product.model`, `ro.board.platform`, `ro.hardware` |
| Kernel | `uname -a` |
| Display resolution / density / refresh | `wm size`, `wm density`, `dumpsys display` (grep for refresh rate) |
| CPU topology | `/proc/cpuinfo`, `/sys/devices/system/cpu/cpu*/cpufreq/related_cpus` |
| `perf_event_paranoid` | `cat /proc/sys/kernel/perf_event_paranoid` -- record it; it gates future hardware-counter work |
| APK sha256, byte size, mtime | computed locally by the server |
| APK version | `aapt`/`aapt2` **only if available**; otherwise skip. Do not add a heavy dependency for this. |
| Installed package info | `dumpsys package <pkg>` (version code, first install time, compilation filter) |
| Device profile applied | verbatim commands + sha256 |
| Server-side provenance | container image tag, server version, adb version (`adb version`), poll interval, timestamps, git commit if injected at build time |
| Raw dumps | store full stdout of the big `dumpsys` calls in a `probes/` subdir rather than trying to parse everything |

Design a single `DeviceProbe` class that returns a `Map<String, dynamic>` so the same code serves `device_before`, `device_after`, and `GET /api/device`.

---

## 8. Status page

One route, `GET /`, serving **server-rendered HTML from a Dart string or a static file**. No framework, no build step, no JS bundler. `<meta http-equiv="refresh" content="10">` is entirely acceptable in v1.

Show: device online/offline + current temperature; whether a run is in progress and which job/run; a table of jobs with state, progress `2/3`, timestamps; per-job links to result files and logs; buttons that `POST` to `/api/queue/next` and `/api/jobs/<id>/cancel`.

Deliberately deferred: charts, violin plots, APK upload UI, metadata composer. The user intends to build a richer frontend later (possibly Jaspr) -- so keep the JSON API complete enough that the HTML page is a *pure client of it*, with no privileged internal access. That's the property that makes the later frontend cheap.

---

## 9. Configuration

Env vars, all with sane defaults, all echoed into `/health` and into every `run.json`:

| Var | Default | Meaning |
|---|---|---|
| `DUT_ADDRESS` | *(required)* | `192.168.x.x:5555` |
| `DATA_DIR` | `/data` | NAS-backed root |
| `PORT` | `8080` | HTTP port |
| `ADB_PATH` | `adb` | Overridable -- **used for testing, see §11** |
| `POLL_INTERVAL_SECONDS` | `15` | Completion polling |
| `DEFAULT_RUN_TIMEOUT_SECONDS` | `1800` | Overridable per job |
| `THERMAL_GATE_CELSIUS` | unset | If set, gate before each run |
| `THERMAL_GATE_TIMEOUT_SECONDS` | `300` | |
| `DEVICE_PROFILE_FILE` | unset | Newline-separated shell commands run on the DUT pre-run |
| `PRECOMPILE_PACKAGE` | `true` | Step 8 |
| `LOG_LEVEL` | `info` | |

---

## 10. Container & deployment

Multi-stage `Dockerfile` in `adb_server/`:

- Stage 1: official Dart SDK image → `dart pub get` → `dart compile exe`.
- Stage 2: slim Debian → copy the binary → install a **pinned** Android platform-tools (download the zip at a fixed version, or a pinned apt package version; record `adb version` at runtime either way). Avoid `latest`.
- Build for **linux/amd64** (the NAS is a Celeron J4125). Add a `--platform` note in the README for anyone building on an ARM Mac.
- `HEALTHCHECK` hitting `/health`.
- Run as a non-root user if practical; note that this affects where the adb key lives.

### Volumes

| Container path | Purpose |
|---|---|
| `/data` | Jobs, results, logs -- a NAS share, visible over SMB |
| `/root/.android` (or the chosen home) | **ADB key persistence -- do not skip this** |

Also provide `docker-compose.yml` (Synology Container Manager reads compose) with `restart: unless-stopped` and the volumes above.

### The ADB authorisation trap -- call this out in the README

The container generates its own `adbkey` on first use. The DUT will report `unauthorized` and, because the rig is headless and unattended, **nobody is there to tap "Allow" at 2am**. Document both fixes:

1. Persist `/root/.android` as a volume, and authorise once interactively (with a display attached) so the grant survives restarts.
2. Or, with root on the DUT, append the container's `adbkey.pub` to the device's `adb_keys` file.

Also document: `adb tcpip 5555` / setting `persist.adb.tcp.port` generally requires root and must survive DUT reboots, and the DUT needs a **static DHCP reservation** so `DUT_ADDRESS` stays valid.

Make the error path good: when `get-state` returns `unauthorized`, the API response and `job.log` must say *exactly* that, and point to the README section. Don't let it surface as a generic non-zero exit code.

---

## 11. Testing

- **A fake adb.** Because `ADB_PATH` is injectable, provide a test fixture script/executable that mimics adb: canned `getprop`/`cat`/`dumpsys` output, a fake sentinel file appearing after N seconds, and injectable failure modes (unauthorized, timeout, crash-without-sentinel, missing result files). **The full run lifecycle must be integration-testable with no hardware present.** This is the single highest-value test asset in the project -- build it early.
- Unit tests for: job ID generation/sorting, `job.json` validation, state transitions, atomic write behaviour, `results_index.json` computation.
- A concurrency test: two simultaneous `POST /api/queue/next` calls → exactly one 202, one 409.
- A crash-recovery test: `running` status on disk at startup → becomes `interrupted`.

---

## 12. Deliverables

```
adb_server/
  REQUIREMENTS.md        # this file
  CONTRACT.md            # the APK↔server contract (§6) -- the user will publish this
  README.md              # setup, Synology deployment, adb auth, troubleshooting, curl examples
  Dockerfile
  docker-compose.yml
  .dockerignore
  pubspec.yaml
  bin/server.dart
  lib/
    config.dart
    job_store.dart       # disk I/O, atomic writes, state machine
    models.dart          # Job, Status, RunMetadata
    adb.dart             # thin typed wrapper over the adb subprocess
    device_probe.dart    # §7
    runner.dart          # §6 lifecycle + mutual exclusion
    api.dart             # shelf router
    web/index.html       # or a Dart string template
  test/
    fixtures/fake_adb/
    ...
  example_job/           # a sample job.json + README showing the drop-folder workflow
```

---

## 13. Style and judgement notes

- **Prefer boring.** Every abstraction must pay for itself in v1. No plugin systems, no event buses, no dependency injection frameworks.
- **Log every adb command and its exit status.** When this rig misbehaves at 3am, `adb.log` is the only witness.
- **Fail loudly, never silently.** A run that produces no data must be `failed` with a reason -- never `done` with empty results. Ambiguity in this layer poisons the science downstream.
- **Never mutate result data.** Not even whitespace trimming.
- **Warnings are first-class.** Every `run.json` has a `warnings: []` array. Unsupported commands, thermal-gate timeouts, and failed `svc power` calls go there and are shown in the UI. The user needs to know which runs were taken under degraded conditions.
- **Schema-version everything** (`job.json`, `status.json`, `run.json`, `results_index.json`). This data is meant to be comparable months from now.

---

## 14. Known open questions -- ask the user

1. Should a failed repetition abort the rest of the job, or continue and record partial success?
2. Should `GET /api/jobs` list archived/completed jobs indefinitely, or is an `archive/` sweep wanted in v1?
3. Exact on-device result directory: is `/sdcard/Android/data/<pkg>/files/...` reliably `adb pull`-able on this build, or is a `run-as`/root fallback needed? (Scoped-storage restrictions since Android 11 make this build-dependent -- worth verifying on the actual device before finalising the pull step.)
4. Is the DUT rooted with a working `su`? This determines whether the device-profile step can pin governors and frequencies at all.
5. Preferred device-profile mechanism: a file of shell commands, or an inline list in config?
6. Should `POST /api/jobs` accept a URL to fetch the APK from, as an alternative to multipart upload?
7. Is an `autorun` mode (drain the queue automatically) wanted behind a config flag in v1, or strictly manual?
8. Should the server capture a Perfetto trace or `dumpsys gfxinfo` alongside runs? (Not needed for CPU microbenchmarks; relevant later for frame timing. Confirm it's out of scope for v1.)
