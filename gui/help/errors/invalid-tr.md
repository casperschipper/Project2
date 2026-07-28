# Octave division too small

The [octave division](fields/octave-division) (tr, tones per octave) must be at least 1.

## Why this matters

Every relative pitch - each [instrument pitch range](fields/instrument-pitch-range) step, each [register](fields/register-list) step, each value in the [row](fields/harmony-row) - is a number from 1 up to this setting. With a value below 1, no relative pitch could ever be valid, and nothing that depends on a step within an octave could be resolved.

## How to fix it

- Set it to at least 1; 12 (standard chromatic tuning) is the conventional starting point.
