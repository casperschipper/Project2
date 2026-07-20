# The highest density is below the lowest

The autonomous [vertical density](concepts/vertical-density) range is inverted: its upper bound is smaller than its lower bound.

## Why this matters

The density range describes how many tones may begin together at one entry point, from the thinnest permitted texture to the thickest. Project Two treats it as a supply to select from: the values from low to high form the stockpile, and the [selection principle](concepts/selection-principles) you attach to density draws from that stockpile for each entry point.

If the high bound is below the low bound, the stockpile is empty. There is no number that is both at least the minimum and at most the maximum, so no density could ever be drawn and no entry point could be populated. Unlike chord size, where the program quietly sorts the two limits, density's bounds are taken as given, because a reversed range here usually means a genuine mistake about what you wanted the texture to do rather than a typo in ordering.

## How to fix it

- Swap the two numbers if you simply entered them in the wrong order.
- Check that you did not edit one bound while thinking of the other: lowering a maximum to `2` after setting the minimum to `4` is the common way to arrive here.
- If you meant a fixed density, set both bounds to the same value. `3 3` means every entry point has exactly three tones.
