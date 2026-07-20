# Octave division

> How many steps the octave is divided into. This defines the pitch grid that registers and compasses are counted in.

PROJECT TWO addresses pitch through a grid. An *absolute pitch* consists of a register digit (1 to 9) and a *relative pitch* — a position within the octave, expressed as a number between 1 and 24. The octave division says how many of those positions actually exist: 12 for the familiar chromatic scale, 24 for quarter tones, and other values for equal divisions in between or beyond.

Relative pitch 0 is reserved and means a percussion instrument — an instrument of indeterminate pitch. It counts as a chord tone for the purposes of [vertical density](concepts/density) but has no position in the grid.

The grid is not only a notational convenience. An automatic check ensures that the number of tones sounding simultaneously in a layer never exceeds the number of tones available in the pitch grid, so the octave division sets a hard ceiling on how thick a layer can become.

## Example

With octave division 12, an [instrument compass](fields/instrument-compass) written as register 1, pitch 01 to register 5, pitch 12 spans from the lowest note of register 1 to the highest note of register 5 — five full octaves, 60 available pitches.

With octave division 24, the same written compass covers only half as much sounding range, because pitch 12 is now the middle of the octave rather than its top. Changing this value therefore re-interprets every compass in the formula; it is not a cosmetic setting.

## Current status

The engine accepts this field but does not yet use it: pitch selection is not implemented in this version, so the value has no effect on the generated score. It is recorded in the structure formula so that formulas written now remain valid, and so that the compasses you enter mean what you intend once pitch is active.

## Related

- [instrument compass](fields/instrument-compass)
- [density](concepts/density)
