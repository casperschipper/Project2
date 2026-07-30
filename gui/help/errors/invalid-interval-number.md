# Interval out of range

A value in a hand-written `(adjacency ...)` matrix entry is outside 1 and `tr - 1`, where `tr` is the [octave division](fields/octave-division).

## Why this matters

The adjacency form of the [interval matrix](fields/harmony-matrix) (`(given (succ succ ...))`) is a compact way to write a mostly-forbidden matrix by hand, listing only the allowed transitions - but both the "given" interval and every "succeeding" interval it lists must be one of the `tr - 1` possible directed intervals (an interval of exactly `tr` wraps back to no movement at all, so it isn't a meaningful value here).

This form is only reachable by editing a `.sexp` file directly - the GUI's own matrix editor always produces a plain grid, never this shorthand.

## How to fix it

- Check every number in the adjacency list is between 1 and `tr - 1` inclusive.
- If the octave division was recently lowered, an adjacency entry written for a larger one may now be out of range.
