# Compass

> The lowest and highest pitch this instrument can play, each written as a register digit and a position within the octave.

A pitch in PROJECT TWO is an *absolute pitch*: a register (1 to 9) plus a *relative pitch*, the position within the octave. How many positions an octave has is set by [octave division](fields/octave-division) — 12 for the chromatic scale, 24 for quarter tones. Relative pitch 0 is reserved and denotes an instrument of indeterminate pitch, that is, percussion.

The compass is a pair of such pitches: the low limit and the high limit. Everything between them is available to the instrument.

## Example

```
guitar1     compass  1 01  to  5 12
basedrum    compass  1 01  to  1 01
```

With octave division 12, `guitar1` spans from the first pitch of register 1 to the twelfth pitch of register 5 — five octaves, sixty available pitches. The bass drum's compass is a single point, which is the natural way to write an instrument that has no pitch of its own.

Note that the same written compass means something different under a different octave division. Under division 24, `5 12` is the middle of register 5, not its top, so the same numbers describe a smaller sounding range. Changing the octave division re-interprets every compass in the formula.

## Current status

The engine accepts and validates the compass but does not yet select pitches: harmony is not implemented in this version, so the compass has no effect on the generated score. It is stored so that formulas remain complete and so that your instrument definitions are ready when pitch selection arrives.

The minimum must not exceed the maximum; the interface reports an inverted compass as an error.

## Related

- [octave division](fields/octave-division)
- [instruments](fields/instruments)
