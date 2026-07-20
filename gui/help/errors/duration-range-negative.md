# An instrument's duration limit is negative

One of the two duration limits declared for this instrument, its shortest or its longest playable duration, is below zero.

## Why this matters

Every instrument declares the band of durations it can actually realise. It is a statement about the player and the instrument, not about the piece: a bowed string can hold a very long tone, a struck percussion instrument cannot, and a wind player's longest note has a practical ceiling.

Project Two uses these limits to filter. When a duration has been drawn from the [duration ensemble](concepts/list-table-ensemble-order) and this instrument is a candidate to play it, the limits decide whether the assignment is possible; if no acceptable value can be found, the score marks a *comment* against a wrong element rather than silently producing something unplayable. A negative bound would make that filter incoherent, since it would admit or reject on the basis of a duration that cannot exist.

## How to fix it

- Correct the negative value. For an instrument with no meaningful lower bound, `0` is the right minimum.
- Check that you have not swapped the two fields; a value that looks wrong is often in the wrong slot, which will also show up as [an inverted range](duration-range-max-below-min).
- Remember that the limits describe the *instrument*, not the piece. Narrowing the piece's rhythmic vocabulary is a job for the [duration list and table](concepts/list-table-ensemble-order).
