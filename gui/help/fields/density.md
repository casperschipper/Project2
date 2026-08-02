# Density

> How many tones begin together at each entry point. Choose an autonomous density with its own range and principle, let the instrument's chord size decide, or - under HARMONY's CHORD principle - let the drawn chord's own size decide.

See [vertical density](concepts/density) for the full discussion. This page covers autonomous and instrument density; the third option, chord-density, has no settings of its own here at all - it's a direct consequence of [HARMONY's CHORD principle](fields/harmony-chord) and can only be reached by switching to that principle on the Harmony screen, which keeps the two in sync automatically (see [chord-principle-density-mismatch](errors/chord-principle-density-mismatch) for what happens if they ever disagree).

## Autonomous

You give a **low** and a **high** bound and a [selection principle](concepts/selection-principles). At each entry point the principle draws a target number of tones from that range. The program then assembles the chord: it picks an instrument, takes as many voices as its chord size allows, and if the target is not met it picks another instrument, and continues until it is. An instrument that would overshoot contributes only the voices still needed. One entry point may therefore involve several instruments, all sharing a single entry delay.

The principle here is a real compositional opportunity. `Alea` gives a flickering, unpredictable thickness. [Group](concepts/group) gives blocks — passages that stay thin, then passages that stay thick. [Tendency](concepts/tendency) gives a curve: a texture that thickens or thins across the whole variant. [Series](concepts/series) guarantees every density in the range is visited equally.

## Instrument density

No range and no principle. Each entry point picks one instrument, and the number of tones is that instrument's own [chord size](fields/instrument-chordsize). Density becomes a consequence of instrumentation. Every chord is by construction something a single instrument can actually play, which is idiomatic but gives up direct control of the texture.

This mode requires **Ins first in the [hierarchy](fields/hierarchy)** — the program reports an error otherwise, since the chord size is not known until the instrument is.

## Example

Autonomous, low 1, high 4, principle `group` (element `series`, repetition `series`, repetitions 1–3):

```
entry point:  1  2  3  4  5  6  7  8  9  10
density:      3  3  1  4  4  4  2  2  1  1
```

At entry point 4, four voices are wanted. `marimba` (chord size 1–4) is picked and supplies 2; `guitar2` (chord size 1–6) is picked and supplies the remaining 2. Four tones, two instruments, one moment.

The same passage under instrument density: entry point 4 picks one instrument and takes whatever its chord size gives — 1 from the bass drum, up to 6 from a guitar, up to 10 from the piano. The density profile becomes a portrait of your instrument list.

## Notes

- Low must be at least 1; high must not be below low.
- Each [layer](concepts/layers) has its own density. The perceived thickness of the variant is the sum across layers.
- A check prevents the superposed tones per layer from exceeding the pitch grid's capacity — see [octave division](fields/octave-division).

## Related

- [vertical density](concepts/density)
- [instrument chord size](fields/instrument-chordsize)
