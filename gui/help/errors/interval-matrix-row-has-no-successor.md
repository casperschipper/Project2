# Interval has no allowed successor

A row of the [interval matrix](fields/harmony-matrix) has no checked cell at all - so once the chain reaches that interval, there is nowhere allowed for it to go next. This is only flagged when the chain can actually land on that interval in the first place - see below.

## Why this matters

Fig. 8-5 of EMR-3 8.2 makes this exact point: a row with no allowed successor is a genuine dead end, and it's the composer's responsibility to avoid one when hand-designing a matrix.

This is only a warning, not an error, because the engine still copes if the chain does reach a dead-end row: it falls back to a fixed choice and marks the result **"INTERVAL RESTRICTIONS TOO STRICT"** rather than crashing or looping forever. But every note produced this way is a note the matrix didn't actually shape - worth noticing rather than relying on.

## Why "no successor" alone isn't enough to flag

A dead-end row is only worth a warning if the chain can actually reach it. There are exactly two ways in:

- As the very first interval - but the engine only ever offers an interval as the first one *if its own row has a successor*, so a dead-end row is never eligible to start the chain.
- Via some other row's transition into it - i.e. this interval's own *column* has a checked cell somewhere.

A dead-end row can never itself be the source of a transition (no successor means no outgoing checks at all), so there's no need to trace multi-step paths - checking the column directly is enough. If a row has no successor **and** nothing anywhere in the matrix transitions into it, the chain can never land there at all, so its lack of a successor is moot - not flagged.

## How to fix it

- Check at least one cell in this row, so the chain always has somewhere allowed to go from this interval.
- If you'd rather leave this interval unreachable altogether, make sure its whole column is unchecked too (nothing transitions into it) - once that's true, this warning stops appearing for it on its own.
