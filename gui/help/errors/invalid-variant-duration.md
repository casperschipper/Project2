# The variant duration must be greater than zero

The [variant duration](concepts/variant) is zero or negative.

## Why this matters

A variant is one realisation of the [structure formula](concepts/structure-formula), and the variant duration is the length in seconds that you declare for it. It is the frame everything else is fitted into. Project Two calculates how many entry points a variant will contain from this duration together with the average entry delay produced by the [selection principle](concepts/selection-principles), and it generates until that frame is filled. If there are several [layers](concepts/union), they all share the same variant duration; that shared span is what makes them simultaneous strands rather than a sequence.

The duration also anchors any [tendency mask](concepts/selection-principles), whose sections divide it into proportional stretches. A mask that rises across the variant is meaningless without a variant to rise across.

A duration of zero leaves no time for entry points, so no tones would be generated at all. Note that the sum of entry delays is not required to match the declared duration exactly; the manual is explicit about that. The declared duration is the target, not an accountancy constraint.

## How to fix it

- Set a positive duration in seconds. A minute is `60`.
- Fractions are accepted as well as decimals, so `90.5` and `181/2` are both valid.
- If you want a longer piece with the same character, change only this value and leave the rest of the formula alone; that is exactly what the variant duration is designed to let you do.
