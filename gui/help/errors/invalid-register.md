# A register is inverted

The lowest pitch given for this register lies above its highest pitch.

## Why this matters

A [register](fields/register-list) is a range between two absolute pitches, and REGISTER's job is to place a relative pitch somewhere inside that range. A reversed register - low above high - describes an empty range: no absolute pitch is both above the minimum and below the maximum, so this entry could never place any relative pitch at all. Exactly like an [instrument's own compass](fields/instrument-compass), the comparison is by octave first and then by step within it, so a register can look plausible and still be inverted, e.g. `4.10` to `4.03`.

## How to fix it

- Swap the two pitches if you entered them in the wrong order.
- Compare the octave digits separately from the steps: `3.20` is below `4.02`, even though 20 is the larger number.
- If you meant a single fixed pitch, write the same pitch twice - that is a valid, if narrow, register.
