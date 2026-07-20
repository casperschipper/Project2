# Performance mode

> Per chord: one mode of performance is drawn and shared by every note of the chord. Per note: a mode is drawn independently for each note.

This is the setting the manual calls MOD-PERF, and it works exactly like [dynamics mode](fields/dynamics-mode) — the same mechanism applied to articulation instead of intensity. It only makes a difference where chords occur; with a [vertical density](fields/density) of 1 the two settings are identical in effect.

**Per chord** treats the chord as a single articulatory object: all its notes are `muted`, or all are `pizzicato`. This is the ordinary reading, and it keeps the chord audible as one sonority with one manner of production.

**Per note** draws separately for each note. A six-note chord may contain two `normal` notes, three `muted` and one `overtone1` — a composite sound in which the same simultaneity is produced several different ways at once. This is a genuinely unusual sonority, and one of the more distinctive things PROJECT TWO can be asked to produce. It is also a demanding one to notate and to play, which is worth remembering if the score is destined for performers rather than for playback.

## Example

Chord of four notes, active group `normal, muted, overtone1, pizzicato`, order principle `series`.

**Per chord** — one draw: `muted`. Four muted notes. The next chord draws `overtone1`. Twelve chords consume twelve values.

**Per note** — four draws for the first chord: `overtone1`, `normal`, `pizzicato`, `muted`. A complete cycle inside one chord: the sonority contains the entire articulatory vocabulary simultaneously. Twelve chords now consume forty-eight values.

The consumption rate is the practical consideration. Any long-range shape the [order](fields/performance-order) principle traces — a [tendency](concepts/tendency), or the block structure of a [group](concepts/group) principle — advances once per *note*, not once per entry point. A `group` principle with repetitions of 2 to 4 will, on chords of six, often complete an entire block within a single chord, so the blocks you intended as passages become internal to individual sonorities. If you want per-note articulation *and* audible articulatory sections, raise the repetition counts substantially.

## Requirement

Per-note requires **`Ins` before `Per`** in the [hierarchy](fields/hierarchy). The number of notes in a chord follows from the chosen instrument's [chord size](fields/instrument-chordsize), so the instrument must be resolved before the program knows how many modes to draw. The interface reports this as an error.

## Related

- [performance order](fields/performance-order)
- [dynamics mode](fields/dynamics-mode) — the same mechanism for dynamics
- [duration relation](fields/duration-relation) — the same mechanism for duration
