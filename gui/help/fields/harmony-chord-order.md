# Order of chords

> SEQ-CHORD, EMR-3 8.2 entry 17: which chord from the table is drawn next.

This field only applies when [principle](fields/harmony-principle) is set to Chord. Unlike the restricted choices some other tables offer, the order chords are drawn in uses the full general [selection principle](concepts/selection-principles) - the same `Alea`/`Series`/`Sequence`/`Ratio`/`Group`/`Tendency` choice every other parameter's own order uses. `Series` visits every chord once before any repeats; `Ratio` favours some chords over others; `Tendency` can drift the piece from sparser chords toward denser ones (or the reverse) over the course of a variant, since [density](fields/density) is entirely a consequence of which chord gets picked.

One transposition interval (see [transposition](fields/harmony-chord-transposition)) is drawn each time as many chords have been drawn as the table has entries - one "pass" through the table - regardless of which chords the order principle actually picked during that pass. With a non-sequential order like `Alea`, a pass may revisit some chords and skip others; this is a deliberate simplification, not a guarantee that every chord is heard exactly once per pass.

## Related

- [harmony principle](fields/harmony-principle)
- [chords](fields/harmony-chord)
- [transposition](fields/harmony-chord-transposition)
