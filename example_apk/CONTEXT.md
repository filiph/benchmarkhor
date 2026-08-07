# Context: Example App Under Measurement

This context covers `example_apk`, the throwaway Flutter app that Benchmarkhor
measures in order to demonstrate and validate itself. Its vocabulary is about
workloads and triggers, not about plotting. For **Trial**, **Session**,
**Variant** and friends, see the [shared experiment
vocabulary](../doc/CONTEXT-SHARED.md).

## Language

**App Under Measurement**:
The Flutter app whose frames are traced to produce a `.benchmark` file. In this
repo there is exactly one, `example_apk`.
_Avoid_: Example app, demo app, sample

**Counter**:
The app's home screen, holding a single integer count that a tap increments.
It is the cheap baseline workload.
_Avoid_: Home page, main screen

**Expensive Route**:
A route that is deliberately unoptimised so that building and scrolling it costs
a lot of frame time. Its slowness is its purpose; it is a fixture, not a screen
to be improved.
_Avoid_: Heavy route, dog page, slow screen

**Threshold**:
The count at which the **Counter** opens the **Expensive Route**. Reaching a
multiple of the threshold re-arms the trigger, so one launch of the app can yield
several **Trials** (of the same **Variant**).
_Avoid_: Limit, trigger point

## Example dialogue

**Dev**: Where do I get the **Trials** from?

**Expert**: Tap the FAB on the **Counter**. Every time the count crosses a
multiple of the **Threshold**, the **Expensive Route** opens, and that build is
the **Trial** we're measuring.

**Dev**: So should I `const` those widgets and switch to a lazy list?

**Expert**: No. The **Expensive Route** is a fixture — optimising it would
destroy the workload. Optimise the **App Under Measurement** anywhere else you
like, just not there.
