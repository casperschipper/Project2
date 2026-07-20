# Every element in this group is blocked

This parameter uses the [ratio](concepts/selection-principles) principle, and every element in this table group has been given a weight of zero.

## Why this matters

Ratio selects at random from a supply, but with each element assigned a factor saying how many times it may be drawn before it leaves the supply. A factor of zero is legitimate and useful: it blocks an element, keeping it in the [list](concepts/list-table-ensemble-order) so that indices elsewhere still line up, while preventing it from ever sounding. Weights are declared per list index, and any index you do not mention defaults to zero, which is why blocking often happens by omission rather than intent.

A group in which *every* element is blocked is different in kind. If the [ensemble](concepts/list-table-ensemble-order) ever selects this group, ratio will have an empty pool to draw from and no value can be produced. This is reported as a warning rather than an error because it is only fatal if the group is actually selected; the shape of the formula is still coherent, and you may be deliberately holding a group in reserve.

## How to fix it

- Give at least one element in this group a non-zero weight, so the group can produce something if it is chosen.
- Check whether the omission was accidental. Because unlisted indices default to zero, adding an element to a group without adding it to the ratio pairs silently blocks it.
- Remove the group from the table if it is genuinely not meant to be used. That is clearer than a group that exists but can never sound, and it also removes it from the count that [combination](concepts/combination) has to align.
