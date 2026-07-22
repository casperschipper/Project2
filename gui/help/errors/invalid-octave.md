# Octave out of range

An octave digit must be between 1 and 9.

## Why this matters

An absolute pitch is written as an octave digit (1-9) plus a relative pitch within it - `401` means octave 4, step 1. The octave digit is a single digit by convention (the manual reserves 1-9 for it), so anything outside that range cannot be part of a valid absolute pitch at all: an [instrument's compass](fields/instrument-compass) or a [register](fields/register-list) built from it could never be resolved.

## How to fix it

- Check the first number in the pitch pair - it should be a single digit, 1 through 9.
- If you meant a higher pitch, raise the relative-pitch (step) digit instead, up to the [octave division](fields/octave-division); the octave digit only selects which octave, not how high within it.
