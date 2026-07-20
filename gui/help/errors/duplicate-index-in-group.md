# A group names the same index more than once

This [table](concepts/list-table-ensemble-order) group contains the same list index twice or more.

## Why this matters

This is allowed, and it is sometimes exactly what you want, which is why it is reported as a warning rather than an error. The manual states plainly that an index may be named more than once within a group.

What it does is weight. The [ensemble](concepts/list-table-ensemble-order) is assembled from the group's elements as written, repetitions included, and the [selection principle](concepts/selection-principles) then works over ensemble positions without regard to which item each one denotes. So under *alea* a doubled index is twice as likely to be drawn; under *series*, which exhausts the supply before repeating, it appears twice in every cycle rather than once. Under [ratio](concepts/selection-principles) the effect compounds, because each occurrence carries its own weight, and the manual warns explicitly that a list item appearing more than once in the ensemble must have its ratio factor mentioned a corresponding number of times.

The warning exists because duplication is easy to introduce by accident while editing a group, and its effect is statistical, spread thinly across the whole [variant](concepts/variant), and therefore almost impossible to notice in the score.

## How to fix it

- Leave it as it is, if the emphasis is intentional. Nothing is broken.
- Remove the repeat if you meant each element to be equally available.
- If you want weighting but want it stated explicitly rather than implied by repetition, use the [ratio](concepts/selection-principles) principle, where the factors are visible and adjustable in one place.
