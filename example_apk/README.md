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

## What comes out

One JSON object per Frame, newline-delimited, honouring
[`adb_server/CONTRACT.md`](../adb_server/CONTRACT.md) — including the `DONE`
sentinel and the `BENCH_DONE` log line:

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

**Two seconds of patience at each end.** The engine batches `FrameTiming`s and
may only deliver them once per second, so the recorder waits before it starts
(discarding start-up Frames) and polls until deliveries stop before it writes.
For the same reason a Frame carries whichever phase was current when its timing
*arrived*, which smears phase boundaries by up to one batch.

## Not done yet

The two-APK `am instrument` flow — `testBuildType = "profile"`,
`assembleProfileAndroidTest`, and a `FlutterTestRunner` shell class — is the
actual target (`adb_server/REQUIREMENTS.md` §6). `flutter drive` is only the
local dev loop.
