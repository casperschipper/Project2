# Duration relation

> How long a tone lasts relative to the entry delay that follows it — independent of it, equal to it, or bounded by it — and whether a chord's notes share one duration or each get their own.

Entry delay and duration are measured from the same time point, and they answer different questions. The entry delay says when the *next* attack arrives. The duration says when *this* tone stops. Nothing forces those two to agree, and the duration relation is where you decide whether they should.

This is not a detail of notation. It is the switch that decides the fundamental articulation of the music: whether it is a seamless chain, a sequence of detached events, or a texture that overlaps itself. Two variants with identical entry delays, identical dynamics and identical instruments can sound like different pieces on the strength of this setting alone.

## The three relations

**Independent.** Durations are drawn from the duration ensemble with no reference to the entry delay at all.

The musical result is mixed and unpredictable in a specific way. Where the drawn duration comes out shorter than its entry delay, the tone stops before the next attack and silence results — a *pseudo rest*, which arises automatically from the arithmetic rather than being placed by you. Where it comes out longer, the tone is still sounding when the next attack arrives, and the texture overlaps itself. Where the two happen to coincide, you get a momentary join. All three occur in the same passage, in proportions you did not directly specify, and the surface is correspondingly varied. This is the most open setting.

**Equals entry.** The duration *is* the entry delay.

Every tone lasts exactly until the next attack: no gaps, no overlaps, an unbroken chain. The duration list is not consulted at all under this relation — durations are no longer a parameter, only a consequence of rhythm. Musically this is the legato setting, and it makes the entry-delay parameter carry the whole articulation of the layer. Because the entire chord takes one shared value, this relation is necessarily per-chord; the per-note choice does not apply.

**Shorter than entry.** The duration is drawn from the duration ensemble, but restricted to values not exceeding the entry delay.

Every tone stops on or before the next attack, so overlap is impossible, but the amount of silence between events varies with what was drawn. This is the setting for detached, articulated writing where you still want to *compose* the lengths rather than inherit them — staccato where you choose how staccato, note by note.

## Which parameter bends

For the two constrained relations, the enforcement direction depends on the [hierarchy](hierarchy). If `Ent` precedes `Dur`, the entry delay is fixed first and durations longer than it are rejected — rhythm is free, duration bends. If `Dur` precedes `Ent`, the duration is fixed first and entry delays shorter than it are rejected instead — length is free, rhythm bends. Where no admissible value exists at all, a wrong element is used and marked with a [comment](fields/comment) in the score.

## Per-chord and per-note

For `independent` and `shorter-than-entry` you also choose how a chord is treated.

**Per-chord.** One duration is drawn and shared by every note of the chord. The chord begins and ends as a block — a single object with a single shape.

**Per-note.** A duration is drawn independently for each note. The notes begin together and release one after another, so the chord dissolves from within. At higher [vertical density](vertical-density) this is a genuinely different sound: attacks stay vertical while releases fan out.

Chord tones can never begin at different times — that is what an entry point means — but they can end at different times, and this is the switch that decides it.

Per-note requires `Ins` to precede `Dur` in the hierarchy, since the number of notes depends on the chosen instrument's [chord size](fields/instrument-chordsize).

## Example

Entry delay `0.5`, duration ensemble `0.1 0.2 0.3 0.5 0.8 5.0`, a chord of three notes.

| relation | result |
|---|---|
| independent, per-chord | all three last `5.0` — a long overlap across the next eight attacks |
| independent, per-note | `0.2`, `5.0`, `0.3` — two short taps and one sustained tone left hanging |
| equals-entry | all three last `0.5`, ending exactly as the next chord enters |
| shorter-than-entry, per-chord | all three last `0.3` — a clean block with 0.2 s of silence after |
| shorter-than-entry, per-note | `0.1`, `0.5`, `0.3` — a staggered release inside a 0.5 s frame |

Note the `5.0` in the ensemble. Under `shorter-than-entry` with these entry delays it can almost never be drawn, so a large part of your duration list is effectively dead. Under `independent` it dominates. The same list means different things under different relations, which is why this setting is worth deciding before you write the durations rather than after.

## Related

- [duration relation field](fields/duration-relation)
- [duration list](fields/duration-list)
- [entry delay list](fields/entrydelay-list)
- [hierarchy](hierarchy)
- [vertical density](vertical-density)
