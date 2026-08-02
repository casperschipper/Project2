# Harmony requires Har first in the hierarchy

[Density](fields/density) is set to chord-density (HARMONY's [CHORD principle](fields/harmony-principle) is active), but Harmony is not the first parameter in the [hierarchy](fields/hierarchy).

## Why this matters

Under CHORD, HARMONY decides a whole chord - tones *and* how many of them - before anything else can be resolved. Every other per-note parameter needs to know how many notes there are before it can be drawn, and under CHORD that count comes from HARMONY itself, not from an instrument's chord size or an autonomous density range. This is the same reasoning as [instrument-density-requires-ins-first](instrument-density-requires-ins-first), just with HARMONY in the driving seat instead of Instrument.

## How to fix it

- Move Harmony to the front of the hierarchy. The remaining order is still entirely yours.
- If you want a different parameter to lead instead, switch [principle](fields/harmony-principle) away from Chord (to Row or Interval) and pick an autonomous or instrument-driven [density](fields/density) instead.

## Related

- [harmony principle](fields/harmony-principle)
- [density](fields/density)
- [hierarchy](fields/hierarchy)
