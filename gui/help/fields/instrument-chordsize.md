# Chord size

> The number of tones this instrument can sound simultaneously, given as a minimum and a maximum.

Chord size is how many voices an instrument contributes when it is picked for an entry point. A bass drum has chord size 1 to 1: one tone, always. A piano might be 1 to 10. A guitar written as 6 to 6 is peculiar and deliberate — it can only ever play six-note chords, never a single line.

The minimum matters as much as the maximum. Setting a minimum above 1 means the instrument is never used monophonically, which is a strong textural decision. Setting minimum and maximum equal fixes the instrument's contribution entirely.

Neither value may be 0; an instrument that plays no notes is not an instrument.

## How it is used

This depends on which [density](fields/density) mode you have chosen, and the difference is significant.

**Instrument density.** The chord size *is* the vertical density. Each entry point picks one instrument and sounds that many tones. Your instrument list becomes, directly, the density profile of the piece — a texture built from bass drum and marimba is thin by construction, one built from guitar1 and piano is thick.

**Autonomous density.** A target density is drawn first, and then instruments are picked until the target is filled. Chord size now determines how many instruments it takes to build a chord. A target of 6 is one guitar1, or six bass drums, or a piano plus a marimba. If the last instrument picked would overshoot the target, only the voices still needed are used — so an instrument may sound below its stated minimum when it is finishing off a chord.

## Example

Instruments: `guitar1` (6–6), `marimba` (1–4), `basedrum` (1–1).

Under **instrument density**, ten entry points might give densities `6 1 3 6 1 2 4 1 6 1` — the profile jumps between the guitar's six-note blocks and the drum's single strokes, and nothing in between is under your control.

Under **autonomous density** with range 1–4: a target of 4 might be filled by the marimba alone, or by four bass drum strokes, or by a marimba taking 3 and a bass drum taking 1. Note that `guitar1` can barely participate — its minimum of 6 exceeds the target — so raising its minimum has quietly excluded it from thin passages.

That last observation is the practical trap. If autonomous density's range is narrower than your instruments' chord size minima, some instruments will rarely or never appear. Check the two against each other.

## Related

- [density](concepts/density)
- [vertical density](concepts/density)
- [instruments](fields/instruments)
