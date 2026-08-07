# Context Map

All contexts speak the [shared experiment vocabulary](./doc/CONTEXT-SHARED.md)
(Experiment, Variant, Treatment, Session, Round, Trial, Frame).

## Contexts

- [Plotting](./CONTEXT.md) — renders benchmark distributions as violin/box plots (`bin/plot.dart`)
- [Example App Under Measurement](./example_apk/CONTEXT.md) — the Flutter app whose frames are timed to produce Trial data

## Relationships

- **Example App Under Measurement → Plotting**: exercising the app produces
  frame timings, which `benchextract` turns into a `.benchmark` file; Plotting
  reads those files. The two contexts share no code, and no terms beyond the
  shared experiment vocabulary.
