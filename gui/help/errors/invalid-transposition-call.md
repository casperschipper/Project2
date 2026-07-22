# Invalid transposition call number

TRANSP-ROW must be a call number from 0 to 4.

## Why this matters

[Transposition](fields/harmony-transposition) is selected by a call number, the same way the manual numbers every other principle: 0 is none, 1 is alea, 2 is series, 3 is chromatic, 4 is serial. A number outside 0-4 doesn't name any of the five transposition behaviours the engine implements.

## How to fix it

- Choose one of the five options from the transposition dropdown rather than entering a number directly, if you are editing the formula file by hand.
