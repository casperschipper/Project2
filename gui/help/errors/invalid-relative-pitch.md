# Relative pitch out of range

A relative pitch in the [row](fields/harmony-row) is outside 1 and the [octave division](fields/octave-division) (tr) - or, if you meant a percussion event, write `p` rather than a number.

## Why this matters

HARMONY's row holds relative pitches - the step within an octave - and there can only be as many distinct steps as the octave division allows. If the octave division is 12, only 1 through 12 are valid steps. `0` is not a valid step and is not treated specially either: percussion is its own explicit entry, `p`, written directly into the row (see [row](fields/harmony-row)).

## How to fix it

- Check the [octave division](fields/octave-division) - lowering it shrinks the valid range for every value already in the row.
- A value above the octave division is usually a typo for a smaller step, or an attempt to write an octave transposition directly into the row instead of relying on [transposition](fields/harmony-transposition).
- A negative value, or `0`, is never a valid step; write `p` if you meant percussion. (With **Count pitches from 0** ticked above the row, the range shown is one lower - 0 to one below the octave division - and the message uses that numbering.)
