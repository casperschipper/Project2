# Register mode

> Per chord: one register is drawn and shared by every note of the chord. Per note: a register is drawn independently for each note.

The same MOD- mechanism as [dynamics mode](fields/dynamics-mode) and [performance mode](fields/performance-mode), applied to REGISTER. **Per chord** gives every note in a chord the same octave range - the chord moves as a block between pitched and unpitched, or between registers, only from one chord to the next. **Per note** lets a single chord mix registers freely, e.g. some notes drawn from a low range and others from a high one, or some pitched notes alongside a percussion note in the same chord.

## Requirement

Per-note requires **`Ins` before `Reg`** in the [hierarchy](fields/hierarchy): the number of notes in a chord depends on the chosen instrument's chord size, so the instrument must be resolved first.

## Related

- [register order](fields/register-order)
- [dynamics mode](fields/dynamics-mode) — the same mechanism for dynamics
