# No instruments are defined

The piece has an empty instrument list.

## Why this matters

The instrument parameter is not one parameter among equals. Every tone in the score belongs to a player, and the instrument decision is what makes a great deal of the rest of the formula meaningful. Chord size, declared per instrument, is what determines how many notes an entry point receives under [instrument density](concepts/vertical-density). The compass filters which pitches are playable. The per-instrument duration limits filter which durations are. Each instrument's own performance modes and dynamics are the subsets of the master lists that this player can actually realise. And any parameter set to be chosen [per note](per-note-requires-ins-first) depends on the chord size the instrument supplies.

With no instruments, all of that has nothing to attach to, and the [instrument table](concepts/list-table-ensemble-order) can hold no valid indices. No variant can be produced.

## How to fix it

- Define at least one instrument, with a name, a chord size, a compass, duration limits, and its available performance modes and dynamics.
- Build the [instrument table](concepts/list-table-ensemble-order) afterwards, since its cells are positions in the list you have just created.
- If the piece is for one player, a single instrument is entirely legitimate; give it a chord size of `1 1` if it is monophonic, and the texture will be a single line.
