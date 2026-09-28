/// Generates the agent-facing `GET /llms.txt` briefing.
///
/// The running container has no Markdown files (see `.dockerignore`), so every
/// prose section here is an authored Dart string constant — not read from
/// `CONTRACT.md` / `REQUIREMENTS.md` at runtime. Keep this dense and imperative:
/// the reader is an LLM agent that has never seen the repo and never will.
library;

import 'dart:convert';

import 'models.dart';

/// One HTTP route exposed by the server. The shelf [Router] is built from
/// [kApiRouteTable], so this inventory cannot drift from the live routes.
class ApiRoute {
  final String method;
  final String path;
  final String purpose;

  const ApiRoute(this.method, this.path, this.purpose);
}

/// Source of truth for both the shelf router registrations and the route
/// inventory embedded in `/llms.txt`.
const List<ApiRoute> kApiRouteTable = [
  ApiRoute(
    'GET',
    '/health',
    'Liveness. Returns uptime, busy flag, config summary.',
  ),
  ApiRoute(
    'GET',
    '/llms.txt',
    'Agent briefing: Session Directory lifecycle, session.json schema, completion contract, build traps. No auth, no adb.',
  ),
  ApiRoute('GET', '/api/sessions', 'List sessions (status summaries).'),
  ApiRoute(
    'POST',
    '/api/sessions',
    'Create a Session from a session.json body; returns 201 with session_id.',
  ),
  ApiRoute(
    'POST',
    '/api/sessions/discover',
    'Scan data dir for Session Directories dropped over SMB; write status.json for new ones.',
  ),
  ApiRoute(
    'GET',
    '/api/sessions/<id>',
    'Full detail: session.json + status.json for one Session.',
  ),
  ApiRoute(
    'POST',
    '/api/sessions/<id>/cancel',
    'Cancel a queued or running Session.',
  ),
  ApiRoute(
    'POST',
    '/api/sessions/<id>/requeue',
    'Move a Session back to queued (rounds_completed reset).',
  ),
  ApiRoute(
    'POST',
    '/api/queue/next',
    'Start the next queued Session if the Runner is idle. 202 or 409 if busy.',
  ),
  ApiRoute(
    'GET',
    '/api/device',
    'Connect to the DUT, probe metadata, cache last_snapshot.json. Use this for live device state.',
  ),
  ApiRoute(
    'GET',
    '/api/sessions/<id>/trials/<trial>/results/<file>',
    'Serve one raw result file (text/plain), byte-for-byte.',
  ),
  ApiRoute(
    'GET',
    '/api/sessions/<id>/trials/<trial>/adb.log',
    'Serve the per-Trial adb command log.',
  ),
  ApiRoute(
    'GET',
    '/api/sessions/<id>/trials/<trial>/logcat.txt',
    'Serve the per-Trial logcat capture.',
  ),
  ApiRoute(
    'GET',
    '/api/sessions/<id>/trials/<trial>/trial.json',
    'Serve the per-Trial metadata JSON.',
  ),
  ApiRoute('GET', '/api/sessions/<id>/log', 'Serve session.log for a Session.'),
  ApiRoute('GET', '/api/logs/server.log', 'Tail of the server log (?lines=N).'),
  ApiRoute(
    'GET',
    '/',
    'HTML dashboard (and /sessions/<id> detail via the Jaspr app).',
  ),
];

/// Hand-written one-line descriptions for every `session.json` field.
///
/// Kept in lockstep with [SessionSpec] by tests: every key present in a
/// default `SessionSpec.toJson()` (plus nullable keys omitted by
/// `includeIfNull: false`) must appear here, and vice versa.
const Map<String, String> kSessionSpecFieldDescriptions = {
  'schema_version':
      'Schema version of this session.json. Currently 1; bump only on breaking changes.',
  'name':
      'Human-readable Session name. Used to build the session ID slug. Required, non-empty.',
  'description': 'Free text shown in the UI. Optional.',
  'variants':
      'Map of variant-name → VariantSpec. Each key is a documentation label (e.g. baseline); values name the APK Pair files. Required.',
  'package':
      'Android applicationId of the App Under Measurement (Variant APK). Required, non-empty.',
  'test_package':
      'Android applicationId of the Bridge (androidTest) APK. Defaults to <package>.test when omitted.',
  // The default below is the Dart-side class an androidTest class is annotated
  // with (@RunWith(FlutterTestRunner.class)), which is NOT the same thing as the
  // instrumentation runner Android registers — that is usually
  // androidx.test.runner.AndroidJUnitRunner. Since the default is therefore
  // wrong for a standard Flutter androidTest setup, the description has to say
  // so out loud: a reader who trusts it discovers the mismatch only when
  // `am instrument` fails on the rig, after the upload.
  'instrumentation_runner':
      'android:name of the <instrumentation> element registered by the Bridge APK — usually androidx.test.runner.AndroidJUnitRunner. DO NOT trust the default shown here: verify it against testInstrumentationRunner in android/app/build.gradle.kts and the <instrumentation> element in src/androidTest/AndroidManifest.xml, and set this to whatever the app actually registers. A wrong value fails at am instrument time, on the rig, after the upload.',
  'launch_activity':
      'Activity component to launch via am start for single-APK variants (e.g. com.example.app.MainActivity or .MainActivity). Defaults to <package>/.MainActivity when omitted for single-APK variants.',
  'rounds':
      'How many Rounds to run. Each Round executes every Variant once (order randomised). Positive integer; default 1.',
  'trial_timeout_seconds':
      'Per-Trial wall-clock timeout. Null/omitted → server default (DEFAULT_TRIAL_TIMEOUT_SECONDS). Optional.',
  'expected_result_files':
      'Filenames the server expects under device_result_dir after a successful Trial. Missing/empty → Trial failed. Default [].',
  'device_result_dir':
      'On-DUT directory where the app writes result files, DONE/FAILED sentinels. Required, non-empty. Typically /sdcard/Android/data/<package>/files.',
  'tags':
      'Free-form string→value map for submitter provenance (flutter version, notes, …). Default {}.',
};

/// Hand-written one-line descriptions for every VariantSpec field.
const Map<String, String> kVariantSpecFieldDescriptions = {
  'apk':
      'Filename of the Variant APK, resolved flat beside session.json (never a subdirectory). Default app.apk.',
  'test_apk':
      'Filename of the Bridge APK (androidTest), resolved flat beside session.json. Optional for single-APK variants; default app-test.apk for instrumentation APK pairs.',
  'source':
      'Optional free-form provenance of the git state this Variant was built from (e.g. "git 4f2a1c9 (dirty)"). Documentation only — nothing resolves it. See ADR 0005.',
};

// ---------------------------------------------------------------------------
// Authored prose (A1)
// ---------------------------------------------------------------------------

const _kWhatIsBenchmarkhor = '''
## What Benchmarkhor's rig is

You stage a Session Directory (session.json + APK files) on the NAS. The adb_server Runner installs each Variant onto a real Android DUT, executes one Trial per Variant per Round in randomized order, and waits for the completion contract. You get raw measurement data (and other result files) pulled byte-for-byte — the server never parses, averages, or summarises measurement data on the device or runner.

Benchmarkhor supports two distinct execution pathways:
1. **Whole Flutter App Benchmark**: Measures UI rendering performance (frame build and raster durations in `frames.jsonl`). Requires an APK Pair (Variant APK + Bridge androidTest APK) launched via `am instrument`.
2. **Pure Dart Benchmark**: Measures algorithmic / CPU performance (iteration durations in `iterations.jsonl`). Requires only a single Harness APK launched via `am start`.
''';

const _kSessionDirectory = '''
## Session Directory lifecycle

The Session Directory is sessions/<session_id>/ on the NAS. It is the only interface a submitter needs: dropping a directory over SMB and calling POST /api/sessions converge on the same on-disk state. Four phases:

1. Staged. Submitter has written session.json and, flat beside it (NEVER in subdirectories), the APK files every Variant names. No status.json yet. Producing this directory is the whole job of preparing an experiment.
2. Discovered. Server sees session.json without status.json and writes one: queued if the spec parses, invalid (parse error recorded, never retried) if not.
3. Filled. Runner appends only: session.log, plus one trials/trial-NNN/ per Trial (trial.json, pulled results, logs). status.json is rewritten atomically as state advances.
4. Terminal. status.json reaches done, failed, cancelled, or interrupted. Partial artefacts stay on disk.

session.json is written once by the submitter and never modified by the server. Repeating an experiment means a new Session Directory.

FLAT LAYOUT RULE: APK filenames in session.json are resolved as p.join(sessionDir, variant.apk) — flat beside session.json. Subdirectories are not searched. Name the files in the VariantSpec accordingly (e.g. "baseline.apk", not "apks/baseline.apk").
''';

const _kSessionId = '''
## Session ID convention

Session ID = directory name = <ISO8601-utc-compact>__<slug>.
Example: 2026-08-03T14-22-05Z__set-contains-enum-vs-object
No colon characters (SMB-safe: 14-22-05, not 14:22:05). Lexicographic sort = chronological sort = FIFO queue order. POST /api/queue/next picks the lexicographically first queued Session.
''';

const _kCompletionContract = '''
## Completion contract (app ↔ server)

After EVERY result file has been written, closed, and flushed — and only then — the app creates a sentinel file named DONE in device_result_dir.

It also prints one line to logcat:
  BENCH_DONE <exit_code> <result_path> <diagnostic_info>
For Flutter apps this is typically:
  BENCH_DONE <exit_code> <result_path> <n> frames
For pure Dart benchmarks:
  BENCH_DONE <exit_code> <result_path> <n> iterations
(The server matches on the BENCH_DONE token; the rest is diagnostic.)

On unrecoverable error: write FAILED (contents = short human reason) instead of DONE, and/or print:
  BENCH_FAILED <reason>
No DONE on failure.

WHY print, not stdout.writeln: an Android app process's file descriptor 1 goes nowhere. print is routed to logcat by the Flutter engine; that is how BENCH_* lines reach adb logcat.

Server detection priority:
1. DONE or FAILED exists in the result directory (adb shell test -f).
2. BENCH_DONE / BENCH_FAILED marker seen in the logcat stream.
3. App process gone (pidof empty) for two consecutive polls with no sentinel → crash → failed (not success).
4. trial_timeout_seconds elapsed → failed; still pull whatever exists.
''';

const _kTwoPathways = '''
## Two execution pathways

Benchmarkhor handles two kinds of benchmarks on the same Android DUT rig:

### Pathway A: Whole Flutter App Benchmark (APK Pair via am instrument)
- **Use case**: UI rendering performance, animations, list scrolling, route transitions.
- **Data contract**: Produces `frames.jsonl` with per-frame build and raster timings.
- **APK requirements**: Needs an **APK Pair** for each Variant:
  - **Variant APK**: Holds the Flutter app and compiled Trial (`flutter build apk --profile -t integration_test/<trial>.dart`). This is the App Under Measurement.
  - **Bridge APK**: The `androidTest` APK. Holds no Dart and no Variant — only `MainActivityTest.java` that launches `MainActivity` so the bundled Trial runs under `am instrument`. The Bridge APK is Variant-agnostic and byte-identical across Variants.
- **Execution**: Launched via `am instrument -w -r <test_package>/<instrumentation_runner>`.
- **session.json**: Requires `package`, `test_package`, `instrumentation_runner`, `expected_result_files: ["frames.jsonl"]`, and each Variant defines both `apk` and `test_apk`.

### Pathway B: Pure Dart Benchmark (Single Harness APK via am start)
- **Use case**: Algorithmic performance, data structures, math, CPU-bound logic, compiler optimizations.
- **Data contract**: Produces `iterations.jsonl` with per-iteration execution durations (`durationUs`).
- **APK requirements**: Needs only a **Single APK** (Harness APK) per Variant:
  - Minimal Flutter/Android app hosting the pure Dart `main()` workload.
  - No Bridge APK, no `androidTest`, and no instrumentation runner.
- **Execution**: Launched directly via `am start -n <package>/<launch_activity>`.
- **session.json**: Requires `package`, `launch_activity` (defaults to `<package>/.MainActivity` if omitted), `expected_result_files: ["iterations.jsonl"]`, and each Variant defines only `apk` (omits `test_apk`).
''';

const _kBuildTraps = '''
## Build traps and recipes

### Common traps for all builds
1. **flutter clean FIRST** before each Variant build. Gradle rewrites the APK zip in place and leaves the previous build's entries as dead space. An arm64 APK rebuilt over a universal one measured 66 MB on disk while holding 26 MB of entries. The rig reinstalls before every Trial, so that slack is paid on every install.

2. **--target-platform android-arm64**. Without it you ship a universal APK with arm64-v8a + armeabi-v7a + x86_64 payloads, of which the DUT uses one.

### Pathway A build recipe (Flutter App APK Pair)
Must set `testBuildType = "profile"` in `android/app/build.gradle.kts`. Use `assembleProfileAndroidTest`, NOT `assembleAndroidTest`. Under the old debug default, Gradle also built a whole debug app APK as a side effect, and the pair only installed because Flutter's profile buildType inherits the debug signing key.

Canonical Pathway A build sketch:
  flutter clean
  flutter build apk --profile --target-platform android-arm64 -t integration_test/<trial>.dart
  (cd android && ./gradlew app:assembleProfileAndroidTest)
  cp build/app/outputs/flutter-apk/app-profile.apk <sessionDir>/<variant>.apk
  cp build/app/outputs/apk/androidTest/profile/app-profile-androidTest.apk <sessionDir>/<variant>-test.apk

### Pathway B build recipe (Pure Dart Single APK)
No androidTest APK, no Bridge APK, and no gradle assembleAndroidTest tasks are needed. Simply build the profile APK:
  flutter clean
  flutter build apk --profile --target-platform android-arm64
  cp build/app/outputs/flutter-apk/app-profile.apk <sessionDir>/<variant>.apk
''';

const _kProfileDebuggable = '''
## Profile builds are debuggable

Flutter's profile buildType is initWith(debug), so the Variant APK ships android:debuggable="true". Absolute numbers are not release-grade. adb shell cmd package compile -m speed is a no-op because ART pins debuggable packages to the verify filter. This is common-mode across Variants and cancels in a baseline-vs-improved comparison. The Dart workload is AOT regardless (libapp.so present, no kernel_blob.bin).
''';

const _kVariantIsGitState = '''
## A Variant is a git state, not a code path (ADR 0005)

Variants compared in a Session are the same Trial built against different git states of one repository (HEAD vs stash, PR branch vs merge base, before/after an uncommitted edit) — not two code paths living side by side in the tree.

- One Trial per performance concern; built N times against N git states.
- The harness goes in FIRST, before any Variant is built.
- Every Variant must be built from a tree whose harness files are byte-identical (else the comparison is silently invalid).
- example_apk is an intentional exemption: it is a self-contained fixture for the rig, not the recommended shape for a real app.

Record which git state each Variant came from in VariantSpec.source (documentation only).
''';

const _kSkillPointer = '''
## Agent workflow

The agent-facing workflow for producing Session Directories, harnesses, and APKs for both pathways is the `filiph-benchmarkhor-prepare-apks` skill. Uploading/running Sessions and analysing results are out of scope of that skill.

Live DUT state: GET /api/device (connects first) or GET /health. This document intentionally carries no device state and performs no adb calls.
''';

// ---------------------------------------------------------------------------
// Generated sections (A2)
// ---------------------------------------------------------------------------

String _typeName(Object? value) {
  if (value == null) return 'null';
  if (value is Map) return 'Map';
  if (value is List) return 'List';
  return value.runtimeType.toString();
}

/// Builds the session.json / VariantSpec field reference from a default
/// model instance's toJson() output, plus explicit handling of nullable
/// fields that `includeIfNull: false` omits.
String _fieldReferenceSection() {
  // Required fields only — @Default values still appear in toJson().
  const sample = SessionSpec(
    name: 'example',
    variants: {'baseline': VariantSpec()},
    package: 'com.example.app',
    testPackage: 'com.example.app.test',
    deviceResultDir: '/sdcard/Android/data/com.example.app/files',
  );
  final sessionJson = sample.toJson();
  final variantJson = const VariantSpec().toJson();

  final buf = StringBuffer()
    ..writeln('## session.json field reference (generated from model)')
    ..writeln()
    ..writeln(
      'Keys come from SessionSpec.toJson() / VariantSpec.toJson() on a '
      'minimally-constructed instance (defaults baked in by @Default). '
      'Nullable fields with no default are absent when null because of '
      'includeIfNull: false; those are listed explicitly below.',
    )
    ..writeln()
    ..writeln('### SessionSpec fields')
    ..writeln();

  final sortedSessionKeys = {
    ...sessionJson.keys,
    ...kSessionSpecFieldDescriptions.keys,
  }.toList()..sort();
  for (final key in sortedSessionKeys) {
    final hasDefaultInJson = sessionJson.containsKey(key);
    final value = sessionJson[key];
    final required = !_sessionOptionalKeys.contains(key);
    final desc = kSessionSpecFieldDescriptions[key] ?? '(MISSING DESCRIPTION)';
    final typeStr = hasDefaultInJson
        ? _typeName(value)
        : (key == 'trial_timeout_seconds' ? 'int?' : 'unknown');
    final defaultStr = hasDefaultInJson
        ? _formatDefault(value)
        : '(absent when null)';
    buf.writeln(
      '- `$key` ($typeStr, required=$required, default=$defaultStr): $desc',
    );
  }

  buf
    ..writeln()
    ..writeln('### VariantSpec fields')
    ..writeln();

  final variantKeys = {
    ...variantJson.keys,
    ...kVariantSpecFieldDescriptions.keys,
  };
  final sortedVariantKeys = variantKeys.toList()..sort();
  for (final key in sortedVariantKeys) {
    final hasDefaultInJson = variantJson.containsKey(key);
    final value = variantJson[key];
    final required =
        false; // all VariantSpec fields are optional with defaults or nullable
    final desc = kVariantSpecFieldDescriptions[key] ?? '(MISSING DESCRIPTION)';
    final typeStr = hasDefaultInJson
        ? _typeName(value)
        : (key == 'source' ? 'String?' : 'unknown');
    final defaultStr = hasDefaultInJson
        ? _formatDefault(value)
        : '(absent when null)';
    buf.writeln(
      '- `$key` ($typeStr, required=$required, default=$defaultStr): $desc',
    );
  }

  // A worked example, encoded from a real SessionSpec rather than typed out, so
  // it cannot disagree with the field table above it. Field names, nesting and
  // the flat APK layout are the three things submitters get wrong, and a
  // copyable example fixes all three faster than prose does.
  final example = SessionSpec(
    name: 'smaller-images-scroll-cost',
    description: 'Does shrinking the product images make scrolling cheaper?',
    package: 'com.example.app',
    testPackage: 'com.example.app.test',
    deviceResultDir: '/sdcard/Android/data/com.example.app/files',
    instrumentationRunner: 'androidx.test.runner.AndroidJUnitRunner',
    rounds: 30,
    expectedResultFiles: const ['frames.jsonl'],
    variants: const {
      'baseline': VariantSpec(
        apk: 'baseline.apk',
        testApk: 'baseline-test.apk',
        source: 'git 4f2a1c9',
      ),
      'improved': VariantSpec(
        apk: 'improved.apk',
        testApk: 'improved-test.apk',
        source: 'git 4f2a1c9 + uncommitted changes at 2026-08-26T10:12:00Z',
      ),
    },
  );

  final pureDartExample = SessionSpec.fromJson({
    'name': 'hash-map-lookup-perf',
    'description':
        'Comparing standard Map vs optimized hashing implementation',
    'package': 'com.example.dart_benchmark_harness',
    'launch_activity': 'com.example.dart_benchmark_harness.MainActivity',
    'device_result_dir':
        '/sdcard/Android/data/com.example.dart_benchmark_harness/files',
    'rounds': 30,
    'expected_result_files': const ['iterations.jsonl'],
    'variants': const {
      'baseline': {
        'apk': 'baseline.apk',
        'source': 'git 4f2a1c9',
      },
      'optimized': {
        'apk': 'optimized.apk',
        'source': 'git 4f2a1c9 + branch-opt',
      },
    },
  });
  final pureDartJson = Map<String, dynamic>.from(pureDartExample.toJson())
    ..remove('test_package');

  buf
    ..writeln()
    ..writeln('### A complete, valid session.json')
    ..writeln()
    ..writeln(
      'Encoded from a real SessionSpec for Pathway A (Flutter App APK Pair). '
      'The four APK files it names sit flat in the same directory as '
      'session.json.',
    )
    ..writeln()
    ..writeln(
      const JsonEncoder.withIndent('  ').convert(
        jsonDecode(
          _encodeJson(example.toJson()),
        ),
      ),
    )
    ..writeln()
    ..writeln('## Example session.json for Pathway B (Pure Dart Single APK)')
    ..writeln()
    ..writeln(
      'Encoded from a real SessionSpec for single-APK pure-Dart benchmarks. '
      'Notice test_apk and test_package are omitted, and expected_result_files specifies iterations.jsonl.',
    )
    ..writeln()
    ..writeln(
      const JsonEncoder.withIndent('  ').convert(
        jsonDecode(
          _encodeJson(pureDartJson),
        ),
      ),
    );

  return buf.toString();
}

/// Keys that may be omitted or have non-required semantics in session.json.
const _sessionOptionalKeys = {
  'schema_version',
  'description',
  'test_package',
  'instrumentation_runner',
  'launch_activity',
  'rounds',
  'trial_timeout_seconds',
  'expected_result_files',
  'tags',
};

String _formatDefault(Object? value) {
  if (value == null) return 'null';
  if (value is String) return '"$value"';
  // Never fall back to Dart's `toString()` for structured values. `toJson()`
  // leaves nested freezed objects (VariantSpec) unconverted, so `toString()`
  // would print `VariantSpec(apk: app.apk, testApk: app-test.apk)` — camelCase
  // field names that do not exist in session.json, contradicting the snake_case
  // names this very document lists two lines later.
  if (value is Map || value is List) return _encodeJson(value);
  return value.toString();
}

/// JSON-encodes [value], converting any nested object that knows how to
/// serialise itself (e.g. [VariantSpec]) rather than stringifying it.
String _encodeJson(Object? value) {
  try {
    return jsonEncode(
      value,
      toEncodable: (Object? o) {
        if (o is VariantSpec) return o.toJson();
        return '$o';
      },
    );
  } on JsonUnsupportedObjectError {
    return '$value';
  }
}

const _kValidationRules = '''
## session.json validation rules (beyond the model)

Applied in _validateSessionSpecJson before freezed parsing:
- name, package, device_result_dir: must be non-empty strings.
- variants: must be a map.
- rounds: must be a positive integer when present (legacy alias: repetitions → rounds).
- expected_result_files: must be a list when present.
- test_package: defaults to <package>.test when omitted.
- launch_activity: optional string component name; defaults to <package>/.MainActivity for single-APK variants.
- trial_timeout_seconds: accepts legacy alias run_timeout_seconds.

A malformed session.json yields state invalid immediately, with the parse error recorded in status.json.error. It is never retried.
''';

/// Returns the full `/llms.txt` document as a plain string.
///
/// Performs no I/O and no adb calls. [gitCommit] is echoed so a reader can
/// tell which server build produced the briefing.
String generateLlmsTxt({
  required String gitCommit,
  DateTime? generatedAt,
  List<ApiRoute> routes = kApiRouteTable,
}) {
  final at = (generatedAt ?? DateTime.now().toUtc()).toIso8601String();
  final buf = StringBuffer()
    ..writeln('# Benchmarkhor adb_server — agent briefing')
    ..writeln()
    ..writeln('generated by adb_server $gitCommit at $at')
    ..writeln()
    ..write(_kWhatIsBenchmarkhor)
    ..writeln()
    ..write(_kTwoPathways)
    ..writeln()
    ..write(_kSessionDirectory)
    ..writeln()
    ..write(_kSessionId)
    ..writeln()
    ..write(_kCompletionContract)
    ..writeln()
    ..write(_kBuildTraps)
    ..writeln()
    ..write(_kProfileDebuggable)
    ..writeln()
    ..write(_kVariantIsGitState)
    ..writeln()
    ..write(_kSkillPointer)
    ..writeln()
    ..write(_fieldReferenceSection())
    ..writeln()
    ..write(_kValidationRules)
    ..writeln()
    ..write(_routesSectionFrom(routes));
  return buf.toString();
}

String _routesSectionFrom(List<ApiRoute> routes) {
  final buf = StringBuffer()
    ..writeln('## HTTP routes')
    ..writeln()
    ..writeln(
      'Generated from kApiRouteTable (the same list the shelf router is built from).',
    )
    ..writeln();
  for (final r in routes) {
    buf.writeln('- `${r.method} ${r.path}` — ${r.purpose}');
  }
  return buf.toString();
}
