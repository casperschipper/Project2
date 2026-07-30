# Chord repeats a tone between two neighbours

The [chord](fields/harmony-matrix) used to derive the interval matrix (CHORD-INT, EMR-3 8.2 example 8-6) has the same tone twice in a row - including the wraparound from its last tone back to its first.

## Why this matters

Deriving a matrix from a chord works by walking the chord as a cycle of tones (in both directions) and computing the interval between each consecutive pair. If two tones next to each other in that cycle are identical, the interval between them would be zero - but the matrix only has cells for intervals 1 through `tr - 1`, so there is nowhere to record that transition.

## How to fix it

- Change one of the two repeated, neighbouring tones so they differ.
- If you want a chord that genuinely contains the same relative pitch twice (e.g. doubled at the octave, which is invisible to HARMONY since it only tracks the step, not the octave), separate the two occurrences with a different tone between them rather than placing them next to each other.
