# Pitch range

> The lowest and highest pitch this instrument can play, each written as an octave and a relative pitch within it.

A pitch in PROJECT TWO is an *absolute pitch*: an octave (1 to 9) plus a *relative pitch*, the position within the octave. How many positions an octave has is set by [octave division](fields/octave-division) — 12 for the chromatic scale, 24 for quarter tones. Percussion is written as an explicit, separate marker rather than any particular pitch - there is no reserved relative-pitch value standing in for "no pitch."

A pitch range is a pair of such pitches: the low limit and the high limit. Everything between them is available to the instrument.

## Example

```
(pitch-range (low (octave 1) (pitch 1)) (high (octave 5) (pitch 12)))
(pitch-range percussion)
```

With octave division 12, the first example spans from the first pitch of octave 1 to the twelfth pitch of octave 5 — five octaves, sixty available pitches. The second is how an instrument with no pitch of its own is written - a bass drum, say - rather than a degenerate single-point range.

Note that the same written pitch range means something different under a different octave division. Under division 24, pitch 12 is the middle of an octave, not its top, so the same numbers describe a smaller sounding range. Changing the octave division re-interprets every pitch range in the formula.

## Current status

The pitch range now actively constrains which instrument can be assigned a resolved pitch: REGISTER and HARMONY resolve a pitch independently of any particular instrument, and an instrument can only take a note whose pitch falls inside its own pitch range (or, for a percussion instrument, only a percussion event) - enforced during instrument assignment.

The minimum must not exceed the maximum; the interface reports an inverted pitch range as an error.

## Related

- [octave division](fields/octave-division)
- [instruments](fields/instruments)
