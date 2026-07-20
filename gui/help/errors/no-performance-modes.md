# This instrument has no performance modes

An instrument was defined without any mode of performance, so there is no way it can articulate a tone.

## Why this matters

Mode of performance is the articulation with which a tone is played, and in Project Two it is a full [parameter](concepts/hierarchy), resolved for every tone just as duration and dynamics are. It has its own [list, table and ensemble](concepts/list-table-ensemble-order) at the level of the piece, and its own [selection principle](concepts/selection-principles).

Each instrument then declares which of the piece's modes it can actually produce. This is a subset relation, and it is how the formula encodes real playing technique: a string player may have arco, pizzicato and sul ponticello available where a percussionist has only its own few strokes. When the program comes to give a tone to an instrument, the mode drawn from the ensemble must be one this player can realise, or the tone is a *wrong element* and the score carries a comment about it.

An instrument with an empty set can satisfy no mode at all. Every tone offered to it fails that test, so it can never legitimately play, even though it still occupies a list position and can still be selected.

## How to fix it

- Give the instrument at least one mode. If it has only one way of playing, name it, for instance `ord` or `normal`.
- Every mode you name must appear in the piece's master performance list, or it will be reported as an [unknown mode](unknown-performance).
- If the instrument is not meant to appear in this piece, remove it from the [instrument table](concepts/list-table-ensemble-order) rather than leaving it unplayable.
