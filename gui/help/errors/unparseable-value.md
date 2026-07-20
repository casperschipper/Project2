# This value is not a number

The text in this field could not be read as a number.

## Why this matters

Time values in Project Two, entry delays, durations, instruments' duration limits and the [variant duration](concepts/variant), are quantities that the program does arithmetic on. It sums entry delays against the variant duration to work out how many entry points a variant will have; it compares durations with entry delays to decide whether a tone overlaps the next entry or leaves a *pseudo rest*; it filters durations against each instrument's declared limits. Text that is not a number can take no part in any of that.

Two spellings are accepted, and they are equivalent. A decimal such as `0.25`, and a literal fraction such as `1/4`. Fractions are supported because rhythmic material is very often conceived proportionally, and writing `1/3` is both more exact and more legible than `0.333333`. The two forms may be mixed freely within one list; `1/2` and `0.5` are the same value.

The usual causes are a stray unit or symbol, a comma used as a decimal separator, a leading dot as in `.25`, or a fraction whose denominator is zero.

## How to fix it

- Write a decimal, using a point: `0.25`, `1.5`, `2`.
- Or write a fraction: `1/4`, `3/8`, `5/3`. Both numerator and denominator may themselves be decimals.
- Remove any units, spaces or other characters. The field expects the number alone.
- Use a point rather than a comma for decimals.
