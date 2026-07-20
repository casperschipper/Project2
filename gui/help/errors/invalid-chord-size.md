# A chord size of zero

An instrument's chord size range has a zero in it. Chord size counts tones, and there is no such thing as a chord of nothing.

## Why this matters

Chord size is the number of tones an instrument can sound at once. It is declared per instrument as a pair of limits, because it is a physical fact about the player: a flute is `1 1`, a violin might be `1 4`, a piano more.

Project Two uses that number in two ways. It determines how many notes an entry point actually receives once an instrument has been chosen, and under [instrument density](concepts/vertical-density) it is also what determines the [vertical density](concepts/vertical-density) of the whole texture. A chord size of zero would mean the instrument is selected for an entry point and then plays nothing there, silently consuming the entry point without producing sound. Worse, if that instrument were the one deciding density, the entry point would have no tones at all and the machinery downstream that assigns pitch, duration and dynamics per note would have nothing to assign to.

If you want an instrument that plays a single line, that is chord size `1 1`, not `0`.

## How to fix it

- Set the minimum to `1` for a monophonic instrument, and both limits to `1 1` if it is always monophonic.
- For an instrument that sometimes plays chords, give the real range, for example `1 4`. Project Two will pick within it.
- If you want the instrument to be silent in this piece, remove it from the [instrument table](concepts/list-table-ensemble-order) instead. Silence is a table decision, not a chord size of zero.
