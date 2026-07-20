# Vertical density

> How many tones begin at the same moment. Either you state it directly, or you let the chosen instrument's chord size decide.

Every entry point in a PROJECT TWO score is occupied by a chord — which may be a chord of one. Vertical density is the number of tones commencing simultaneously at that point, counted across the whole [layer](layers) and regardless of how they are distributed among instruments. Percussive sounds of indeterminate pitch count like any other chord tone.

It is the parameter that decides whether a variant is a line, a texture, or a wall.

This page is an orientation. The full treatment — how the program scores a chord across several instruments, what each mode costs you, and a worked example — is in [density](density).

## The two modes, in brief

**Autonomous.** You give a low and a high, plus a [selection principle](selection-principles) that draws a target density from that range for each entry point. The program then assembles a chord of exactly that many tones, taking voices from one instrument and moving on to another if the first cannot supply enough. Density becomes a parameter you can shape: put [tendency](tendency) on it and the texture thickens or thins across the variant; put [group](group) on it and you get blocks of consistent thickness.

**Instrument-derived.** You state no number. Each entry point picks one instrument and the number of tones is that instrument's own [chord size](fields/instrument-chordsize). Density becomes a consequence of instrumentation rather than a parameter in its own right — you give up the density curve and get, in exchange, chords that are always idiomatic, because each is one instrument playing something it can actually play. Since chord size is a property of the instrument, this mode requires `Ins` to come first in the [hierarchy](hierarchy), and the program enforces it.

## Things worth knowing early

- Density is **per layer**. With [union](union) off, each layer has its own density and the perceived thickness of the variant is their sum. Two layers at density 2 are not the same experience as one layer at density 4: the first is two strands of dyads, the second one strand of tetrachords.
- Density interacts with the [duration relation](duration-relation) more strongly than with anything else. High density plus long durations saturates almost immediately; the same durations at density 1 leave audible space. If a variant sounds like undifferentiated mass, look at this pair before touching the pitch material.
- An automatic check prevents the total number of superposed tones per layer from exceeding the number of tones available in the pitch grid.
- With autonomous density, the whole chord shares a single entry delay even when several instruments contributed to it. One entry point is one moment, always.

## Related

- [density](density) — the full account, with the chord-scoring procedure and a worked example
- [density field](fields/density)
- [instrument chord size](fields/instrument-chordsize)
- [layers](layers)
- [hierarchy](hierarchy)
