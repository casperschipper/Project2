# The density asks for more simultaneous tones than there are instruments

The highest autonomous [vertical density](concepts/vertical-density) is greater than the number of instruments defined.

## Why this matters

Vertical density is the number of tones beginning together at an entry point. Under *autonomous* density you set that number yourself, as a range, and it is drawn independently of who is playing, which is what distinguishes it from [instrument density](instrument-density-requires-ins-first) where the chord size of the chosen instrument decides.

Independence does not mean the number is free of consequences. The tones still have to be given to players, and if the required count exceeds what the available instruments can collectively produce, some tones cannot be placed and appear in the score as *wrong elements* carrying comments.

This is a warning, not an error, for two reasons. Instruments with a chord size above one can contribute several tones each, so a density of six may be perfectly playable by three instruments; and the high bound is a ceiling that a [selection principle](concepts/selection-principles) may rarely or never reach, especially under a [tendency mask](concepts/selection-principles) that spends most of the variant elsewhere in the range. Only the count of instruments is compared here, so this warning is deliberately conservative.

## How to fix it

- Add instruments, if you want the thick texture to be reliably realisable.
- Lower the high bound of the density range to something the ensemble can support.
- Leave it, if your instruments have chord sizes above one and can supply the tones between them.
- Consider *instrument density* instead, which derives the count from the chord sizes and so can never ask for more than the players can give.
