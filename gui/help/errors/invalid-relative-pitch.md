# Relative pitch out of range

A relative pitch in the [row](fields/harmony-row) is outside 1 and the [octave division](fields/octave-division) (tr) - or, if you wrote 0 expecting a percussion event, check it landed where you meant it to.

## Why this matters

HARMONY's row holds relative pitches - the step within an octave - and there can only be as many distinct steps as the octave division allows. If the octave division is 12, only 1 through 12 are valid steps; 0 is reserved separately, as the row's own way of marking a percussion event (see [row](fields/harmony-row)).

## How to fix it

- Check the [octave division](fields/octave-division) - lowering it shrinks the valid range for every value already in the row.
- A value above the octave division is usually a typo for a smaller step, or an attempt to write an octave transposition directly into the row instead of relying on [transposition](fields/harmony-transposition).
- A negative value is never valid; use 0 for percussion instead.
