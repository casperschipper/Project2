# An instrument's pitch range is inverted

The lowest pitch given for this instrument lies above its highest pitch.

## Why this matters

The pitch range is the range of pitches an instrument can play, given as two absolute pitches: an octave digit plus a relative pitch within the octave. Project Two uses it as a filter. When a pitch has been decided for a tone and an instrument is to play it, the pitch range says whether that assignment is possible; if it is not, either another instrument is found or the score records a *comment* marking the tone as a wrong element.

A reversed pitch range makes that filter empty. No pitch is both above the minimum and below the maximum, so this instrument could never legally play any pitch at all. It would either be silently skipped in every instrumentation decision or accumulate comments across the whole score. Since the check compares octaves first and then the relative pitch within the octave, a pitch range can look correct at a glance and still be inverted: octave 4 pitch 10 to octave 4 pitch 3 shares an octave but reverses within it.

## How to fix it

- Swap the two pitches if you entered them in the wrong order.
- Check the octave digits separately from the relative pitches: octave 3 pitch 20 is below octave 4 pitch 2, even though 20 is larger than 2.
- If you meant to restrict the instrument to a single pitch, write the same pitch twice; that is a valid, if narrow, pitch range.
