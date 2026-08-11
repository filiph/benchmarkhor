# The Superquantile tail is interpolated, not a top-k average

The p95 Superquantile of a Trial is the mean of its worst 5% of Frames, and 5%
of a Frame count is almost never a whole number: 703 Frames give a tail of
35.15 Frames. We take the worst 35 Frames at full weight plus the 36th at a
weight of 0.15, rather than rounding the tail to a whole number of Frames. We
chose the interpolated tail because rounding makes the Metric jump whenever a
single Frame crosses the tail boundary, and that jump is largest exactly where
Frame counts are smallest — the per-phase aggregates, which are the noisiest
numbers we produce and the reason we wanted a Superquantile in the first place.
A top-k average would have been easier to explain, but it would have reintroduced
the sensitivity to a single Frame that the p95 already suffers from.

## Consequences

Superquantile values are only comparable across Sessions that were extracted with
the same definition; changing it later means re-extracting every Session rather
than comparing old numbers against new ones. For Trials or phases of 20 Frames or
fewer the tail collapses to the single worst Frame, so the Superquantile equals
the maximum there — this is not special-cased, and it means the Metric carries no
more information than `max` for very short phases.

We added the Superquantile expecting it to vary less across Trials than the p95,
and measured on a ten-Round Session it does — but only for build timing, where
the spread of the `route_build` phase fell from 21% to 6%. For raster timing the
Superquantile is marginally *noisier* than the p95, because the worst 5% of
raster Frames are genuine jank spikes and averaging them inherits their spread,
whereas the p95 is capped by whichever Frame happens to sit at the tail boundary.
That is the Superquantile working as intended rather than an argument against it —
the p95 is steady there because it is blind to how bad a spike is — but the
low-variance claim should not be read as universal.
