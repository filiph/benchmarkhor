# Context Map

## Contexts

- [Plotting](./CONTEXT.md) — renders benchmark distributions as violin/box plots (`bin/plot.dart`)
- [Example App Under Measurement](./example_apk/CONTEXT.md) — the Flutter app whose frames are traced to produce sample data

## Relationships

- **Example App Under Measurement → Plotting**: exercising the app produces a
  timeline, which `benchextract` turns into a `.benchmark` file; Plotting reads
  those files. The two contexts share no code and no terms.
