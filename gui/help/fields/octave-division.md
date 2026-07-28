# Octave division

> How many steps the octave is divided into. This defines the pitch grid that registers and pitch ranges are counted in.

PROJECT TWO addresses pitch through a grid. An *absolute pitch* consists of an octave digit (1 to 9) and a *relative pitch* — a position within the octave, expressed as a number between 1 and 24. The octave division says how many of those positions actually exist: 12 for the familiar chromatic scale, 24 for quarter tones, and other values for equal divisions in between or beyond.

Percussion - an instrument, or a moment in the row, of indeterminate pitch - is its own explicit marker rather than any particular relative pitch. It counts as a chord tone for the purposes of [vertical density](concepts/density) but has no position in the grid.

The grid is not only a notational convenience. An automatic check ensures that the number of tones sounding simultaneously in a layer never exceeds the number of tones available in the pitch grid, so the octave division sets a hard ceiling on how thick a layer can become.

## Example

With octave division 12, an [instrument's pitch range](fields/instrument-pitch-range) written as octave 1 pitch 1 to octave 5 pitch 12 spans from the lowest note of octave 1 to the highest note of octave 5 — five full octaves, 60 available pitches.

With octave division 24, the same written pitch range covers only half as much sounding range, because pitch 12 is now the middle of the octave rather than its top. Changing this value therefore re-interprets every pitch range in the formula; it is not a cosmetic setting.

## Current status

Octave division is live: it sets the valid range (1 up to this value) for every relative pitch entered anywhere - an instrument's pitch range, a register's bounds, each value in the row - and the engine rejects any relative pitch outside it.

## Related

- [instrument pitch range](fields/instrument-pitch-range)
- [density](concepts/density)
