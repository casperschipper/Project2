# Harmony mode

> Per chord: one relative pitch is drawn from the row and shared by every note of the chord. Per note: a relative pitch is drawn independently for each note.

The same MOD- mechanism as [dynamics mode](fields/dynamics-mode) and [register mode](fields/register-mode), applied to HARMONY. **Per chord** treats a chord as a single point in the row - one value drawn, one pitch class for the whole chord (each note still gets its own octave from REGISTER, if register mode is per-note). **Per note** draws separately for each note in the chord, so a single chord can contain several different steps of the row at once - and, since the row is consumed once per note rather than once per chord, it is used up (and transposed) several times faster.

## Requirement

Per-note requires **`Ins` before `Har`** in the [hierarchy](fields/hierarchy): the number of notes in a chord depends on the chosen instrument's chord size, so the instrument must be resolved first.

## Related

- [row](fields/harmony-row)
- [register mode](fields/register-mode) — the same mechanism for register
