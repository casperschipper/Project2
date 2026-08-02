# Chords

> TAB-CHORD, EMR-3 8.2 entry 16: the table of chords HARMONY draws from, one whole chord per entry point.

This field only applies when [principle](fields/harmony-principle) is set to Chord. Unlike [Row](fields/harmony-row) and [Interval](fields/harmony-matrix), which each produce one relative pitch at a time, CHORD produces a whole chord at once - every note at that entry point comes from the same draw, and the chord's own size *becomes* the vertical density for that entry point (see [density](fields/density)). This is why CHORD makes HARMONY the main parameter: nothing else can know how many notes there are until HARMONY has decided.

Any number of chords can be given, one per group. Each entry within a chord is either a relative pitch (1 to the [octave division](fields/octave-division)) or the literal token `p`, marking a percussion event - the same vocabulary [Row](fields/harmony-row) uses. A chord may freely mix `p` and real pitches: percussion instruments genuinely participate alongside melody instruments in "scoring" a mixed chord (EMR-3 8.16), each contributing whichever of the chord's tones match what they can play. A chord consisting entirely of `p` is allowed too.

A chord whose *first* entry is `p` is excluded from [transposition](fields/harmony-chord-transposition) entirely, regardless of what follows it - the manual's own rule for keeping a genuinely percussion-only chord from ever being nudged into pitched territory.

## Related

- [harmony principle](fields/harmony-principle)
- [order of chords](fields/harmony-chord-order)
- [transposition](fields/harmony-chord-transposition)
- [density](fields/density)
