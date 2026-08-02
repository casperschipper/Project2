# Chord too long

One of the chords in the [chord table](fields/harmony-chord) has more tones than the [octave division](fields/octave-division) allows.

## Why this matters

EMR-3 caps a chord's size at the pitch grid itself: "maximum number of tones per group = pitch grid tr". Beyond that, a chord could only repeat relative pitches it has already used, which the format has no way to represent meaningfully.

## How to fix it

Shorten the chord to at most as many entries as the octave division, or raise the octave division if you genuinely need a bigger pitch grid.

## Related

- [chords](fields/harmony-chord)
- [octave division](fields/octave-division)
