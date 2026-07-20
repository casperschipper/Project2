# Instrument density needs Instrument first in the hierarchy

[Vertical density](concepts/vertical-density) is set to come from the instruments' chord sizes, but Instrument is not the first parameter in the [hierarchy](concepts/hierarchy).

## Why this matters

There are two ways to decide how many tones begin at an entry point. *Autonomous* density draws the number from a range you declare, independently of who is playing. *Instrument density* takes the number from the chord size of whichever instrument was selected: a violin able to play four notes at once produces up to a four-note chord, a flute produces one.

Under instrument density, the instrument decision is not merely one parameter among several. It is the decision that determines how many tones exist at this entry point, and therefore how many times every other per-note parameter has to be resolved. That makes it logically prior to everything else. If some other parameter were resolved first, it would have to be resolved before anyone knew how many notes it was resolving for.

This is the same reasoning that governs [per-note parameters](per-note-requires-ins-first), only stronger: those need Instrument merely to come *before* them, while instrument density needs it to come first of all.

## How to fix it

- Move Instrument to the front of the hierarchy. The remaining order is still entirely yours.
- If you want a different parameter to be the main parameter and lead the piece, switch density to *autonomous* and give it an explicit range and [selection principle](concepts/selection-principles). Density then no longer depends on the instruments.
- Note that autonomous density and chord size are not in conflict: with autonomous density, chord sizes still limit what each individual player can contribute to the required total.
