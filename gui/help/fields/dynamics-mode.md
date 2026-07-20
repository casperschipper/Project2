# Dynamics mode

> Per chord: one dynamic is drawn and shared by every note of the chord. Per note: a dynamic is drawn independently for each note.

This is the setting the manual calls MOD-DYN, and it decides whether a chord is a single dynamic object or an aggregate of independently weighted voices. It only has an effect where chords occur — with a [vertical density](fields/density) of 1 throughout, the two settings are indistinguishable.

**Per chord** is the ordinary reading of a dynamic marking: the chord has *a* dynamic, and every note in it is played at that level. Chords read as balanced sonorities and the dynamic shape of the layer is a succession of clear levels.

**Per note** draws separately for each note. A six-note chord may contain a `ppp`, three `mf` and two `ff`. The chord ceases to be a block and becomes an internally weighted sonority, in which some notes stand out and others recede. Repeated chords of the same pitches will be differently balanced each time, so the harmony appears to shift colour without changing content.

The musical difference is considerable and worth hearing directly: build a formula with density 4 to 6, set dynamics to `series`, and generate it twice, once in each mode.

## Example

Chord of four notes, active dynamics group `p mf f ff`, order principle `series`.

**Per chord** — one draw: `f`. All four notes at `f`. The next chord draws `p`, all four notes at `p`. Twelve chords consume twelve values, so the `series` cycle turns over every four chords and each dynamic level is heard as a whole-chord event.

**Per note** — four draws for the first chord: `mf`, `ff`, `p`, `f`. One complete `series` cycle inside a single chord. The chord contains the entire dynamic vocabulary at once; the next chord contains it again in a different arrangement. Note the consequence for the principle: twelve chords now consume forty-eight values, and any long-range shape the [order](fields/dynamics-order) principle was tracing — a [tendency](concepts/tendency), for instance — is compressed into a quarter of the events.

That last point deserves attention. Per-note mode does not merely add internal variety; it consumes the selection principle four to six times as fast. A tendency that gave a gradual crescendo per-chord will, per-note, complete its arc long before the layer ends and then restart. Adjust the shape accordingly.

## Requirement

Per-note requires **`Ins` before `Dyn`** in the [hierarchy](fields/hierarchy). The number of notes in a chord depends on the chosen instrument's [chord size](fields/instrument-chordsize), so the instrument must be resolved before the program knows how many dynamics to draw. The interface reports this as an error.

## Related

- [dynamics order](fields/dynamics-order)
- [performance mode](fields/performance-mode) — the same mechanism for articulation
- [duration relation](fields/duration-relation) — the same mechanism for duration
