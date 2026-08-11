# Profile builds are measured as debuggable

Every **Variant APK** Benchmarkhor measures is built with `flutter build apk
--profile`, and Flutter's `profile` buildType is declared `initWith(debug)`. The
APK therefore ships `android:debuggable="true"` and a 1.7 MB
`libvmservice_snapshot.so`. We measure it that way anyway, rather than overriding
the buildType to strip the debug flag.

The alternative is one line of Gradle. What it costs is the local dev loop:
`flutter attach` and `flutter drive --profile` both need the VM service, and
[ADR 0002](0002-the-app-measures-itself.md) already conceded that `flutter drive`
is the only way to iterate on a **Trial** without a full NAS-and-Orange-Pi round
trip. Trading that away to chase a distortion we have no evidence is material
seemed like the wrong side of the bargain — particularly because the distortion
is *common-mode*: both **Variants** in a **Session** carry the identical flag, so
whatever it costs, it costs both, and a baseline-versus-improved comparison
subtracts it out. Benchmarkhor exists to compare two Variants, not to publish
absolute frame times.

It is also a smaller distortion than it looks. `--profile` is a genuine AOT
build — `lib/arm64-v8a/libapp.so` is machine code and there is no
`kernel_blob.bin` — so the Dart that renders the **Expensive Route**, which is
the entire workload, is unaffected by a flag that governs how ART treats the
Java/Kotlin embedding.

`--release` was never a candidate: instrumentation cannot launch a release build
(`adb_server/REQUIREMENTS.md` §1).

## Consequences

Absolute numbers out of this rig are not release-grade and must not be quoted as
"what users will see". They are only meaningful as a difference between two
**Variants** measured the same way.

Step 8 of the run lifecycle, `adb shell cmd package compile -m speed -f <pkg>`,
is a no-op. ART pins debuggable packages to the `verify` compiler filter and
ignores the request. The step is harmless and stays in the sequence, but it buys
nothing while this decision stands.

Reversing this is one Gradle override, but it is not free: a Variant built
without the flag is not comparable to any **Session** recorded before the change.
Flip it only at a deliberate break point, and re-run the baseline on the other
side of it.

If the flag is ever suspected of mattering, the honest experiment is to run one
Session each way on the same device and compare — not to reason about it.
