# Principle

> HARM, EMR-3 8.2 entry 15: which mechanism produces HARMONY's stream of relative pitches.

EMR-3 defines three harmonic principles for HARMONY - CHORD, ROW and INTERVAL. ROW and INTERVAL are "occasionally both placed under the heading of 'row principles'" and behave alike in every way that matters elsewhere in this interface: vertical density stays independent of HARMONY, and neither has a "per chord" mode - every note in a chord always takes its own next value. CHORD is fundamentally different: it becomes the *main* parameter and takes over vertical density itself (how many notes sound at once) - see [chords](fields/harmony-chord).

**Row** is the simplest of the three: a fixed sequence of relative pitches, written out once, that gets used up in order and then transposed as a whole, over and over. See [row](fields/harmony-row) and [transposition](fields/harmony-transposition).

**Interval** produces an unending chain instead: starting from a random tone, each subsequent tone is reached by an interval chosen according to a matrix of which intervals are allowed to follow which. See [matrix](fields/harmony-matrix), [forbidden tones](fields/harmony-forbidden-tones) and [invert matrix](fields/harmony-invert-matrix).

**Chord** produces a whole chord at once, per entry point, from a table you write out - its own size becomes the vertical density right there, so [density](fields/density) switches to reflect that automatically. See [chords](fields/harmony-chord), [order of chords](fields/harmony-chord-order) and [transposition](fields/harmony-chord-transposition).

## Related

- [harmony row](fields/harmony-row)
- [harmony matrix](fields/harmony-matrix)
- [chords](fields/harmony-chord)
