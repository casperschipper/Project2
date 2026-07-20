# An instrument's compass is inverted

The lowest pitch given for this instrument lies above its highest pitch.

## Why this matters

The compass is the range of pitches an instrument can play, given as two absolute pitches: an octave digit plus a relative pitch within the octave. Project Two uses it as a filter. When a pitch has been decided for a tone and an instrument is to play it, the compass says whether that assignment is possible; if it is not, either another instrument is found or the score records a *comment* marking the tone as a wrong element.

A reversed compass makes that filter empty. No pitch is both above the minimum and below the maximum, so this instrument could never legally play any pitch at all. It would either be silently skipped in every instrumentation decision or accumulate comments across the whole score. Since the check compares registers first and then the relative pitch within the register, a compass can look correct at a glance and still be inverted: `4 10` to `4 3` shares a register but reverses within it.

## How to fix it

- Swap the two pitches if you entered them in the wrong order.
- Check the register digits separately from the relative pitches. `3 20` is below `4 2`, even though 20 is larger than 2.
- If you meant to restrict the instrument to a single pitch, write the same pitch twice; that is a valid, if narrow, compass.
