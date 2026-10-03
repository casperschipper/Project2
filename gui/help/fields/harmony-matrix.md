# Matrix

> TAB-INT, EMR-3 8.2 entries 21-22: which intervals may follow which, walked as an unending chain.

The INTERVAL principle never repeats a fixed sequence the way [ROW](fields/harmony-row) does. Instead it walks a chain: starting from a randomly chosen tone, each following tone is reached by adding an interval to the last one - and which interval is allowed to come next depends only on the interval that was *just used*, according to this matrix. A checked cell at row *i*, column *j* means "interval *j* may immediately follow interval *i*". Rows and columns both run from 1 to one less than the [octave division](fields/octave-division) - an interval equal to the octave division itself would just wrap back to no movement at all.

Two ways to build the same matrix:

- **Matrix** - toggle cells directly. Most matrices are mostly forbidden with a handful of allowed transitions per row (a fully-open matrix makes every tone equally reachable from every other, which tends to sound closer to plain randomness than a deliberately shaped harmony).
- **Derive from chord** - give a chord instead (e.g. `1 3 7`), and the matrix is built from that chord's own interval content: walk the chord as a cycle of tones in both directions, and every consecutive pair of intervals along each direction becomes an allowed transition. For the chord `1 3 7` (with 12 tones per octave) this produces the transitions `2→4`, `4→6`, `6→2` (forward) and `6→8`, `8→10`, `10→6` (backward). The resulting matrix is shown live below the chord as you edit it - a read-only preview, not something to hand-toggle directly. A **"Use as editable matrix"** button next to it forks whatever it's currently showing into a fresh hand-editable matrix, for when the derived starting point is close but not quite what you want. Switching back to **Matrix** does the same: the derived matrix is carried over as the starting grid and the chord itself is dropped (an empty grid if the chord isn't valid yet).

Either way, the matrix is shown side by side as the checkbox grid described above and as the **Interval graph**, which lays the same intervals out in a circle with arrows for each allowed transition (a small loop for an interval allowed to follow itself). The graph makes a dead end - an interval with no outgoing arrow at all - much easier to spot than scanning a row of checkboxes, and it follows every click in the grid. In matrix mode, an **[Invert](fields/harmony-invert-matrix)** button above them flips every checkbox at once - a one-shot action on the cells themselves, not a setting kept separately - and **Clear all** unchecks every cell, to start over (it asks first, as there is no undo).

Next to it, the **Row preview** (marked *Preview*) shows one possible row: the relative pitches 1 to the [octave division](fields/octave-division) sit around it like a clock, and each step of the row is an arrow from one tone to the next. Lines the row keeps returning to get darker, tones it never reaches stay empty, and [forbidden tones](fields/harmony-forbidden-tones) are dashed. The filled circle is the first tone, the ring the last. It follows the admission rules below, but without REGISTER or INSTRUMENT (condition 2), and a red dashed arrow marks the "too strict" fallback.

- **Steps** sets how long the row is (32 by default, at most 128).
- **Another variant** draws a fresh row.
- Click a tone to make the row start there; click it again to go back to a random start.

The score draws its own random numbers, so its pitches will differ - the preview shows the kind of row the matrix makes, not the one the score will contain.

## Admission

Whether a new tone from the matrix may actually be used depends on three conditions, checked in this order, each one relaxed only if nothing satisfies all of them so far:

1. **Not a forbidden tone** ([forbidden tones](fields/harmony-forbidden-tones)) - never relaxed.
2. **Agrees with REGISTER or INSTRUMENT**, whichever already resolved - the same percussion-agreement HARMONY always respects, symmetric with how it constrains REGISTER/INSTRUMENT when it runs first.
3. **Not already sounded** since every reachable tone last cycled through once - a soft preference against repeating too soon, dropped first if nothing else satisfies it.

If even ignoring all three conditions the given interval's row in the matrix has no allowed successor, the chain still produces a tone rather than stopping - flagged **"INTERVAL RESTRICTIONS TOO STRICT"** (see [the matrix-row warning](errors/interval-matrix-row-has-no-successor) for how to avoid this).

## Related

- [harmony principle](fields/harmony-principle)
- [forbidden tones](fields/harmony-forbidden-tones)
- [invert matrix](fields/harmony-invert-matrix)
