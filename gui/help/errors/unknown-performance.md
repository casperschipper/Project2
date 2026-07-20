# A performance mode that is not in the list

An instrument, a [table](concepts/list-table-ensemble-order) cell, or a [ratio](concepts/selection-principles) weight names a mode of performance that does not appear in the piece's master performance list.

## Why this matters

Modes of performance, articulations, are declared once at the top level of the [structure formula](concepts/structure-formula) as a master list, and everything else refers to that list. The instrument definitions say which of those modes each player is capable of; the performance table groups indices into it; the score printout draws the name from it.

Keeping one authoritative list is what makes the parameter coherent across the piece. If an instrument could invent a mode of its own, the master list would no longer describe the vocabulary of the piece, the performance table's indices would point at a list that different instruments disagreed about, and a mode could silently appear in the score that you never declared. The rule is a subset rule: each instrument's modes must be drawn from the master list, and may be fewer, which is exactly how you express that a given player cannot do a given articulation.

## How to fix it

- Add the mode to the master performance list, if it genuinely belongs to the piece's vocabulary.
- Correct the spelling on the instrument. Mode names are matched exactly, so `pizz` and `pizz.` are two different modes.
- Remove the mode from this instrument if the player cannot in fact produce it. An instrument with fewer modes is normal; an instrument with [no modes at all](no-performance-modes) is not.
