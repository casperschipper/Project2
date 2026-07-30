# Interval has no allowed successor

A row of the [interval matrix](fields/harmony-matrix) has no checked cell at all - so once the chain reaches that interval, there is nowhere allowed for it to go next.

## Why this matters

Fig. 8-5 of EMR-3 8.2 makes this exact point: a row with no allowed successor is a genuine dead end, and it's the composer's responsibility to avoid one when hand-designing a matrix (the manual also notes that if a row is entirely forbidden, the *column* with the same index should usually be forbidden everywhere too, or the dead end just gets reached again immediately).

This is only a warning, not an error, because the engine still copes if the chain does reach a dead-end row: it falls back to a fixed choice and marks the result **"INTERVAL RESTRICTIONS TOO STRICT"** rather than crashing or looping forever. But every note produced this way is a note the matrix didn't actually shape - worth noticing rather than relying on.

## How to fix it

- Check at least one cell in this row, so the chain always has somewhere allowed to go from this interval.
- If this interval is never meant to be reached (e.g. nothing else in the matrix ever transitions into it), the warning is harmless and can be ignored.
