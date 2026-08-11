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
thing under investigation and in nothing else. In practice, Benchmarkhor
prefers to package each Variant as its own APK.
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
**Baseline**, randomly interleaved. The **Session** (or its runner) is
responsible for installing, running, and uninstalling the correct APK for each
**Trial**.
_Avoid_: Run, job, execution

**Round**:
One complete pass over all **Variants** within a **Session**. Interleaving means
a Session is a sequence of Rounds, not a sequence of Variants. Since each
**Variant** is its own APK, a **Round** involves multiple `adb install` and
`adb uninstall` cycles.
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

### The measurements

**Metric**:
One number summarising all the **Frames** of a single **Trial** — a mean, a
minimum, a maximum, a percentile, a **Superquantile**. A Metric turns a Trial
into a point that can be compared with the same Metric of another Trial. It says
nothing about *which* timing of a Frame is being summarised; build timing and
raster timing are each summarised by the full set of Metrics.
_Avoid_: Statistic, aggregate, measure, score

**Superquantile**:
The **Metric** that averages the worst tail of a **Trial**'s **Frames**. The p95
superquantile is the mean of the worst 5% of Frames, so unlike the p95 it is
sensitive to *how* bad the bad Frames are, and it varies far less from Trial to
Trial than the single Frame a percentile happens to land on. Where a percentile
answers "how bad is the frame at the edge of the tail", a Superquantile answers
"how bad is the tail".
_Avoid_: CVaR, expected shortfall, tail mean, average excess

## Flagged ambiguities

**"Sample"** is banned. It was used for both a **Trial** (in
`example_apk/CONTEXT.md`) and a **Frame** timing (in `adb_server/CONTRACT.md`),
one word at two granularities. Use **Trial** or **Frame**.

**"Temperature"** is not a **Metric**. The device temperature recorded at the
end of each **Round** is an observation of the **Treatment** drifting over a
**Session** — a covariate, something to check the Experiment against, not a
result of it. It is written alongside the Metrics and plotted with them, but it
summarises no **Frames** and it belongs to a Round rather than a **Trial**.

**"Run"** is resolved. `adb_server`'s on-disk layout used to spend it on
`runs/run-NNN/` and its `job.json` had a `repetitions` field meaning "how many
times the server executes the whole APK" — which was close to, but not the same
as, a **Session**. We have now renamed these to `trials/trial-NNN/` and
`session.json` with a `rounds` field to align with this vocabulary.
Prefer **Session**, **Round**, or **Trial**.

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
