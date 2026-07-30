# Unrecognised harmony principle

The `(principle ...)` field under `(harmony ...)` in a hand-written `.sexp` file is not `row` or `interval`.

## Why this matters

HARMONY (EMR-3 8.2) supports the ROW and INTERVAL principles here (CHORD is out of scope - see [harmony principle](fields/harmony-principle)). This name selects which one the rest of the `(harmony ...)` block belongs to, so it has to be exactly one of those two words.

This is only reachable by editing a `.sexp` file directly - the GUI's own [principle](fields/harmony-principle) selector only ever writes one of the two valid names.

## How to fix it

- Change the value to `row` or `interval`, whichever this formula is actually using.
