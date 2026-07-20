# Vertical density

> How many tones begin at the same moment. Either you specify it directly, or you let the chosen instrument's chord size decide.

Every entry point in a PROJECT TWO score is occupied by a chord — which may be a chord of one. *Vertical density* is the number of tones commencing simultaneously at that point, counted across the whole layer and regardless of how they are distributed among instruments. Percussive sounds of indeterminate pitch count as chord tones like any other.

Density is the parameter that decides whether your piece is a line, a texture, or a wall. It is worth setting deliberately rather than inheriting it, because it interacts with everything: a dense variant with long durations saturates immediately, while the same durations at density 1 leave audible space.

## Two ways to obtain it

**Autonomous density.** You give a range — a low and a high — and a [selection principle](concepts/selection-principles) that draws a target density from that range for each entry point. The program then "scores" the chord: it picks an instrument, takes as many voices from it as its chord size allows, and if that is not yet enough, picks another instrument, and another, until the target is reached. If the last instrument would overshoot, its extra voices are simply not used, so the total lands exactly on the target. One entry point can therefore involve several instruments, and the whole chord shares a single entry delay.

**Instrument-derived density.** You do not state a number. Each entry point picks one instrument, and the number of tones is that instrument's own chord size. A guitar with chord size 6 contributes six notes; a bass drum with chord size 1 contributes one. Density becomes a *consequence of instrumentation* rather than a parameter in its own right. Because chord size is a property of the instrument, this mode requires `Ins` to be first in the [hierarchy](concepts/hierarchy) — the program enforces this.

The choice between them is a real compositional fork. Autonomous density lets you compose a density *curve* (put [tendency](concepts/tendency) on it and the texture thickens or thins across the variant; put [group](concepts/group) on it and you get blocks of consistent thickness). Instrument-derived density gives up that control in exchange for a texture that is always idiomatic — every chord is one instrument playing something it can actually play.

## Example

Autonomous, low 1, high 4, principle `group` with element `series`, repetition `series`, repetitions 1–3.

The density values 1, 2, 3, 4 are exhausted before repeating, and each is held for 1–3 consecutive entry points:

```
entry point:  1  2  3  4  5  6  7  8  9  10
density:      3  3  1  4  4  4  2  2  1  1
```

Entry point 4 needs four voices. The program picks `marimba` (chord size 1–4) and takes, say, 2; still two short, it picks `guitar2` (chord size 1–6) and takes 2 more. Four tones, two instruments, one entry delay, one moment.

Compare instrument-derived density with the same instruments. Entry point 4 picks `marimba` alone and produces between 1 and 4 tones — never more, never combined with another instrument at that instant.

## Limits

An automatic check prevents the total number of superposed tones per layer from exceeding the number of tones available in the pitch grid. Note also that with several [layers](concepts/layers), each layer has its own density; the perceived density of the variant is their sum.

## Related

- [density field](fields/density)
- [instrument chord size](fields/instrument-chordsize)
- [layers](concepts/layers)
