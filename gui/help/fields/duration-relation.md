# Duration relation

> How a tone's duration relates to the entry delay that follows it — independent, equal to it, or bounded by it — and whether a chord's notes share one duration or each get their own.

Entry delay and duration are measured from the same time point. The entry delay says when the *next* attack comes; the duration says when *this* tone stops. Their relationship decides the fundamental articulation of the music: whether it is a legato chain, a series of detached events, or something free.

## The three relations

**Independent.** Durations are drawn from the duration ensemble with no reference to the entry delay at all. If a duration comes out shorter than its entry delay, silence results — a *pseudo rest*, which arises automatically rather than being placed. If a duration comes out longer, the tone is still sounding when the next attack arrives, and the texture overlaps. This is the most open setting and produces the most varied surface.

**Equals entry.** The duration is the entry delay. Every tone lasts exactly until the next attack: no gaps, no overlaps, a continuous chain. The duration list is not consulted for this relation. Because the whole chord takes a single shared value, this relation is necessarily per-chord — the per-note choice does not apply.

**Shorter than entry.** The duration is drawn from the duration ensemble but restricted to values not exceeding the entry delay. Every tone stops on or before the next attack, so there is never an overlap, but the amount of silence varies. This is the setting for detached, articulated writing where you still want to compose the lengths.

For the two constrained relations the enforcement direction depends on the [hierarchy](fields/hierarchy). If `Ent` precedes `Dur`, durations longer than the fixed entry delay are rejected. If `Dur` precedes `Ent`, entry delays shorter than the fixed duration are rejected instead. Where no admissible value exists, a wrong element is used and marked with a [comment](fields/comment).

## Per-chord and per-note

For `independent` and `shorter-than-entry` you also choose how a chord is treated:

**Per-chord.** One duration is drawn and shared by every note of the chord. The chord begins and ends as a block.

**Per-note.** A duration is drawn independently for each note. The notes begin together and release one after another, so the chord dissolves from within.

Chord tones can never begin at different times — that is what an entry point means — but they can end at different times, and this is the switch that decides it.

Per-note requires `Ins` to precede `Dur` in the hierarchy, since the number of notes depends on the chosen instrument's [chord size](fields/instrument-chordsize).

## Example

Entry delay `0.5`, duration ensemble `0.1 0.2 0.3 0.5 0.8 5.0`, chord of three notes.

| relation | result |
|---|---|
| independent, per-chord | all three last `5.0` — a long overlap into the next eight attacks |
| independent, per-note | `0.2`, `5.0`, `0.3` — two short taps and one sustained tone |
| equals-entry | all three last `0.5`, ending exactly as the next chord enters |
| shorter-than-entry, per-chord | all three last `0.3` — a clean block with 0.2 s of silence after |
| shorter-than-entry, per-note | `0.1`, `0.5`, `0.3` — a staggered release inside a 0.5 s frame |

## Related

- [duration list](fields/duration-list)
- [entry delay list](fields/entrydelay-list)
- [hierarchy](fields/hierarchy)
