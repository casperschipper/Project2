# Interval restrictions too strict

Some notes in the score you just generated actually hit HARMONY's INTERVAL principle fallback, marked **"INTERVAL RESTRICTIONS TOO STRICT"**: at that point in the chain, the given interval's row in the [matrix](fields/harmony-matrix) had no allowed successor left to move to.

## Why this matters

Unlike [the matrix-row warning](errors/interval-matrix-row-has-no-successor), which flags a dead end just by looking at the matrix's shape, this is a fact about the score that was *actually generated* just now - it also catches the case the static check can't see: a row that does have an allowed successor on paper, but where every one of those successors happens to be a [forbidden tone](fields/harmony-forbidden-tones), which is just as much of a dead end at run time.

It's only a warning because the engine still copes - it falls back to a fixed choice rather than crashing or looping forever - but every note produced this way is a note the matrix didn't actually shape.

## How to fix it

- Check the matrix for the row(s) most likely responsible (start with any flagged by [the matrix-row warning](errors/interval-matrix-row-has-no-successor)) and give them a real successor.
- If a row's only successors are all forbidden tones, either open up the matrix for that row or reconsider whether that tone needs to be forbidden at all.
- Since this depends on the random seed and what actually got drawn, a formula can sometimes generate cleanly and sometimes not - regenerate (or change the seed) to see whether it was a one-off or a real structural issue with the matrix.
