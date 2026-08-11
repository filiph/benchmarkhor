# example_apk

The **App Under Measurement**: a throwaway Flutter app that exists so
Benchmarkhor has something real to measure. Its **Expensive Route** is a frozen
fixture — see [ADR 0001](../doc/adr/0001-expensive-route-is-a-frozen-fixture.md)
before "improving" it.

Vocabulary (Trial, Frame, Variant, Session) lives in
[`doc/CONTEXT-SHARED.md`](../doc/CONTEXT-SHARED.md); the app's own terms are in
[`CONTEXT.md`](./CONTEXT.md).

## Tests

| Directory | What it is |
|---|---|
| `test/` | Widget tests on the synthetic clock. Correctness only, never timing. |
| `integration_test/` | One **Trial** on a real device: ten taps on the Counter, then ten screens of flinging down the Expensive Route, recording every **Frame**. |

### The four moving parts

Four files with confusingly similar names are involved in running a Trial, and
they are not alternatives to each other:

| File | Role | Needed by |
|---|---|---|
| `integration_test/expensive_route_trial_test.dart` | The Trial itself, baseline **Variant**. Becomes the **Variant APK**'s entrypoint. | both flows |
| `integration_test/expensive_route_trial_test_optimized.dart` | The same Trial against the optimised **Variant**. A Variant is chosen at build time, so a second Variant needs a second file and a second APK. | both flows |
| `test_driver/integration_test.dart` | Empty by design. `flutter drive` demands a `--driver` argument; this satisfies it and does nothing else. See [ADR 0002](../doc/adr/0002-the-app-measures-itself.md). | `flutter drive` only |
| `build/app/outputs/apk/androidTest/profile/app-profile-androidTest.apk` | The **Bridge APK**. Contains no Dart and no Variant — just `MainActivityTest.java`, which launches `MainActivity` so the bundled Trial runs. | `am instrument` only |

So there are two flows sharing one workload:

```
flutter drive (local dev loop)          am instrument (the rig)
  test_driver/integration_test.dart       Bridge APK -> MainActivityTest
            |                                   |
            +--------> MainActivity <-----------+
                            |
              the Trial compiled into the Variant APK
                            |
                   frames.jsonl + DONE
```

`flutter drive` builds its own throwaway Bridge APK and never touches the staged
one. The two Dart Trial files are near-identical on purpose; if you change the
workload in one, change it in the other, or the **Variants** stop being
comparable and nothing will warn you.

## Running the Trial

```sh
flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/expensive_route_trial_test.dart \
    --profile --keep-app-running

adb pull /sdcard/Android/data/com.example.example_apk/files/frames.jsonl
```

`--keep-app-running` is **required**. Without it `flutter drive` uninstalls the
app when the Trial ends, and uninstalling wipes `/sdcard/Android/data/<pkg>/`
together with every Frame in it.

`--profile` matters too: debug-mode numbers are meaningless. Drop it only when
you're checking that the Trial *runs*, not what it measures.

## Building for `adb_server`

To generate the **APK Pair** (a **Variant APK** plus a **Bridge APK**) for the
benchmarking rig:

```sh
# Baseline
flutter clean
flutter build apk --profile --target-platform android-arm64 \
    -t integration_test/expensive_route_trial_test.dart
cd android && ./gradlew app:assembleProfileAndroidTest && cd ..
cp build/app/outputs/flutter-apk/app-profile.apk staging/baseline.apk
cp build/app/outputs/apk/androidTest/profile/app-profile-androidTest.apk staging/baseline-test.apk

# Optimized
flutter clean
flutter build apk --profile --target-platform android-arm64 \
    -t integration_test/expensive_route_trial_test_optimized.dart
cd android && ./gradlew app:assembleProfileAndroidTest && cd ..
cp build/app/outputs/flutter-apk/app-profile.apk staging/improved.apk
cp build/app/outputs/apk/androidTest/profile/app-profile-androidTest.apk staging/improved-test.apk
```

The **Bridge APK** is Variant-agnostic (via `MainActivityTest.java`): it launches
`MainActivity`, and whichever Trial was bundled into the **Variant APK** by `-t`
is what runs. It is copied twice above only so each Variant directory is
self-contained — the two files are byte-identical.

Three details in there are not decoration:

**`flutter clean` first.** Gradle packages the APK incrementally, rewriting the
zip in place and leaving the previous build's entries behind as dead space. An
arm64 APK rebuilt over a universal one measured 66 MB on disk while holding only
26 MB of entries. The rig installs the pair before *every* Trial, so that slack
is paid for on every install.

**`--target-platform android-arm64`.** Without it you get a universal APK with
`arm64-v8a`, `armeabi-v7a` and `x86_64` payloads (66 MB of entries), of which the
DUT uses one (26 MB). Drop the flag to go back to universal if you ever want to
smoke-test the pair on an x86_64 emulator, or switch to `--split-per-abi` to keep
both options at the cost of ABI-suffixed filenames in the `cp` lines above.

**`assembleProfileAndroidTest`, not `assembleAndroidTest`.** `testBuildType =
"profile"` in `android/app/build.gradle.kts` moves the Bridge APK onto the
profile buildType. Under the old `debug` default, Gradle also built an entire
debug app APK as a side effect and dropped `app-debug.apk` next to the
`app-profile.apk` you are copying — and the pair only installed at all because
Flutter's profile buildType inherits the debug signing key. The Bridge APK's
build type cannot affect measurements (it holds no Dart and no native code), but
the mismatch was a signing accident waiting to happen.

A sample `session.json` is provided in `staging/`.

## What comes out

One JSON object per Frame, newline-delimited, honouring
[`adb_server/CONTRACT.md`](../adb_server/CONTRACT.md) — including the `DONE`
sentinel and the `BENCH_DONE` log line, and, if the Trial throws, a `FAILED` file
carrying the reason plus a `BENCH_FAILED` log line instead:

```json
{"phase":"scroll","frameNumber":615,"vsyncStart":1809551368,"buildStart":...,
 "buildUs":2146,"rasterUs":1914,"vsyncOverheadUs":...,"totalSpanUs":...,
 "layerCacheBytes":0,"pictureCacheBytes":0}
```

`phase` tags each Frame with the part of the Trial it belongs to
(`counter_taps`, `route_build`, `scroll`, `rest`). The device does no averaging,
sorting or filtering whatsoever; every Frame is emitted verbatim and all
interpretation happens on the host.

## Design notes

**The app measures itself.** There is no `traceAction` and no profiling driver
script, because `traceAction` needs a host VM-service connection and the rig this
feeds is meant to run under `adb shell am instrument` with no Flutter SDK on the
host. `test_driver/integration_test.dart` therefore carries no logic — it exists
only so `flutter drive` has something to point at locally.

**No `pumpAndSettle`.** The Trial sets
`framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive` and waits in
real wall-clock time. `pumpAndSettle` drives frames as fast as the CPU allows,
which floods the raster thread and makes `rasterDuration`, `vsyncOverhead` and
`totalSpan` artefacts of the harness rather than measurements. The price is that
the scroll extent is approximate, so the Trial asserts on `ScrollPosition.pixels`
rather than assuming an exact offset.

**A profile build is still `debuggable`.** Flutter's `profile` buildType is
`initWith(debug)`, so the **Variant APK** ships `android:debuggable="true"` and a
`libvmservice_snapshot.so`. This is deliberate — it is what lets `flutter attach`
and the local `flutter drive` loop work — and both Variants carry it equally, so
it is common-mode and cancels in a baseline-versus-improved comparison. Two
consequences worth knowing: absolute numbers here are not release-grade, and
`adb shell cmd package compile -m speed` is a no-op, because ART pins debuggable
packages to the `verify` compiler filter. The Dart workload is AOT regardless,
which you can confirm by finding `lib/*/libapp.so` and no `kernel_blob.bin`
inside the APK. See
[ADR 0004](../doc/adr/0004-profile-builds-are-measured-as-debuggable.md).

**Two seconds of patience at each end.** The engine batches `FrameTiming`s and
may only deliver them once per second, so the recorder waits before it starts
(discarding start-up Frames) and polls until deliveries stop before it writes.
For the same reason a Frame carries whichever phase was current when its timing
*arrived*, which smears phase boundaries by up to one batch.

## Not done yet

The two-APK `am instrument` flow is now buildable: `testBuildType = "profile"`,
`assembleProfileAndroidTest` and the `MainActivityTest.java` shell class are all
in place, and that flow is the actual target (`adb_server/REQUIREMENTS.md` §6).
What remains untested is the flow itself — no Trial has yet been launched via
`adb shell am instrument` end to end. `flutter drive` is still the local dev loop.

When that first `am instrument` run happens, check that the `BENCH_DONE` line
reaches `adb logcat`. It is emitted with `print` rather than `stdout.writeln`
precisely because an Android app's file descriptor 1 goes nowhere, but that has
not been verified on a device.
