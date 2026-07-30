# The number of variants must be at least 1

The number of variants is not a whole number of 1 or more.

## Why this matters

[Number of variants](fields/n-variants) (EMR-3 9.8, N-VARIANTS) says how many variants this run produces - it names a count of things to generate, not a quantity that can be fractional, zero, or negative. Zero variants would mean generating nothing at all, which isn't a meaningful request; a fraction or a negative number doesn't name any count of variants either.

## How to fix it

- Enter a whole number of 1 or more. `1` (the default - a single variant, generated exactly as before this field existed) is just as valid as any larger count.
