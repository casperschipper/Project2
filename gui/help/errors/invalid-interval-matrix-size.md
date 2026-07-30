# Interval matrix is the wrong size

The [interval matrix](fields/harmony-matrix) is not a square grid of exactly `tr - 1` rows and `tr - 1` columns, where `tr` is the [octave division](fields/octave-division).

## Why this matters

The INTERVAL principle (EMR-3 8.2, entries 21-24) walks a chain of directed intervals - values from 1 to `tr - 1` (an interval of exactly `tr` is indistinguishable from no movement at all, since it wraps back to the same tone). The matrix records, for every possible interval, which intervals are allowed to follow it - so it must have exactly one row and one column per possible interval, no more and no fewer.

In the GUI this should never actually happen - the matrix editor automatically resizes whenever the octave division changes, keeping every cell that still fits. This check exists mainly for a hand-edited project file or an imported `.sexp` whose matrix was written for a different octave division.

## How to fix it

- Open the Harmony screen and re-toggle a cell (or change the octave division and back) to force the matrix to resize itself.
- If editing the `.sexp` by hand, make sure the `(rows (...))` block has exactly `tr - 1` rows, each with exactly `tr - 1` cells.
