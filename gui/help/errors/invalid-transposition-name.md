# Invalid transposition

TRANSP-ROW must be one of: `none`, `alea`, `series`, `chromatic`, or `serial`.

## Why this matters

[Transposition](fields/harmony-transposition) is written as one of these five explicit names, the same way every other selection principle in this interface is spelled out (`alea`, `series`, ...) rather than numbered - the manual's own TRANSP-ROW call numbers (0-4) are not used here. A name outside this list doesn't select any of the five transposition behaviours the engine implements.

## How to fix it

- Choose one of the five options from the transposition dropdown rather than typing a name directly, if you are editing the formula file by hand.
- Check for a typo - the five valid spellings are exactly `none`, `alea`, `series`, `chromatic`, `serial`.
