# The Expensive Route is a frozen fixture

`example_apk` exists to produce sample benchmark data, so its Expensive Route is
written deliberately badly (nothing const, an eager `ListView` of 1000 items, ten
thousand `Text` widgets) and we treat that code as frozen rather than as something
to improve. We chose a stable workload over exemplary code because `.benchmark`
files are only comparable across runs if the work being measured is identical;
"improving" the route would silently invalidate every baseline recorded before
the change.

## Consequences

Two const lints are suppressed for the whole of `lib/expensive_route.dart`, and
the file carries a banner comment warning readers off. If the fixture ever does
need to change, existing baselines must be discarded and re-recorded rather than
compared against new runs.
