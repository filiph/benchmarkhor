# Shared Language: Experiment Vocabulary

The language every context in this repo speaks when talking about *what is being
measured and how the measuring is organised*. It is borrowed, deliberately, from
experimental biology: benchmarking is an experiment, and the discipline that
makes biology's numbers trustworthy is the discipline this rig needs.

Most of these levels are **not implemented yet**. This document is the agreed
vocabulary, not a description of existing code.

## Language

### The design

**Experiment**:
The whole investigation: a hypothesis, the **Variants** chosen to test it, and
the **Treatment** they are run under. It is the unit that has a *question*.
_Avoid_: Test, benchmark suite, study

**Variant**:
One arm of the comparison: a single thing under test. Two Variants differ in the
thing under investigation and in nothing else. Whether a Variant ships as its own
APK or as a branch inside one APK is packaging, not vocabulary.
_Avoid_: Version, build flavour, arm, condition

**Baseline**:
The **Variant** that serves as the control — the one every other Variant is
compared against.
_Avoid_: Before, reference build, control group

**Treatment**:
The conditions a **Variant** is exposed to: the device, its CPU governor and
clocks, environment options. Held identical across all Variants within an
**Experiment**.
_Avoid_: Setup, config, environment

### The execution

**Session**:
One running of the rig, from something like `adb install` through to a batch of
data coming back. A Session exercises several **Variants**, including the
**Baseline**, randomly interleaved.
_Avoid_: Run, job, execution

**Round**:
One complete pass over all **Variants** within a **Session**. Interleaving means
a Session is a sequence of Rounds, not a sequence of Variants.
_Avoid_: Cycle, sweep, pass

**Trial**:
One timed exposure of one **Variant** — e.g. opening the **Expensive Route**
once and scrolling it. The smallest thing that has a *result*.
_Avoid_: Traversal, sample, measurement, repetition

**Iteration**:
A technical replicate: the same work repeated verbatim and measured, such as
calling a tiny function 10 000 times in a loop. Iterations only exist where
repetition is meaningful; a **Trial** that renders a sequence of different
**Frames** has no Iterations.
_Avoid_: Loop, rep

**Frame**:
A frame. The rig records each one's build and raster timing, so a **Trial**
yields many Frames, each different from the last.
_Avoid_: Sample, tick, data point

## Flagged ambiguities

**"Sample"** is banned. It was used for both a **Trial** (in
`example_apk/CONTEXT.md`) and a **Frame** timing (in `adb_server/CONTRACT.md`),
one word at two granularities. Use **Trial** or **Frame**.

**"Run"** is unresolved. `adb_server`'s on-disk layout spends it on
`runs/run-NNN/` and its `job.json` has a `repetitions` field meaning "how many
times the server executes the whole APK" — which is close to, but not the same
as, a **Session**. Until that is settled, prefer **Session**, **Round**, or
**Trial**, and read `run-NNN` as `adb_server`'s own word.

## Example dialogue

**Dev**: I want to know if lazy-loading that list helps. What do I build?

**Expert**: Two **Variants** — the current build is your **Baseline**, the lazy
one is the other. Same **Treatment** for both: same phone, same pinned clocks.
Together with your hypothesis, that's the **Experiment**.

**Dev**: And I run the baseline ten times, then the new one ten times?

**Expert**: No — that hands you the phone's thermal curve as your result. One
**Session**, ten **Rounds**, and each Round runs both Variants in random order.

**Dev**: So a Round gives me two numbers.

**Expert**: A Round gives you two **Trials**, and each Trial gives you every
**Frame** it rendered, with build and raster timing. No averaging on the device.

**Dev**: Where do **Iterations** come in?

**Expert**: They don't, here. An Iteration is the same work repeated verbatim —
useful for a hot function, meaningless for a scroll where every Frame is
different.
