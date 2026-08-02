# Transposition

> How the whole chord table is transposed each time every chord in it has been drawn once (TRANSP-CHORD, entry 18).

This field only applies when [principle](fields/harmony-principle) is set to Chord. It works exactly like [Row's own transposition](fields/harmony-transposition): once a full pass through the table has elapsed (see [order of chords](fields/harmony-chord-order)), a transposition interval is drawn and added to a running total, which is then applied fresh to the *original*, as-written table for the next pass - never compounded against an already-transposed intermediate pass. The composer-written starting tones are always the reference point.

Only 4 modes are offered here, fewer than Row's 5:

- **None** - the table repeats completely unchanged, pass after pass.
- **Alea** - a fresh random interval is drawn for each pass.
- **Series** - every possible interval is used once before any repeats.
- **Given** - an explicit list of intervals you provide yourself, cycled one per pass. This is *not* the same as Row's "Serial" mode (which reuses the row's own values) - CHORD's given list is always separately authored.

Within a chord that does get transposed, any `p` (percussion) entries stay put - only the real pitches shift. A chord whose very first entry is `p` is excluded from transposition altogether, regardless of what follows (see [chords](fields/harmony-chord)).

## Related

- [harmony principle](fields/harmony-principle)
- [chords](fields/harmony-chord)
- [order of chords](fields/harmony-chord-order)
- [row's own transposition](fields/harmony-transposition)
