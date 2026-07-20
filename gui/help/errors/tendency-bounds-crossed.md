# A tendency section's bounds are reversed

Within one [tendency](concepts/selection-principles) section, a minimum bound lies above its corresponding maximum.

## Why this matters

Each section of a tendency mask defines a window over the [ensemble](concepts/list-table-ensemble-order) at two moments: where the window sits when the section begins, and where it has arrived when the section ends. Each of those is a pair, a lower and an upper edge, both given as [proportions of the list](tendency-out-of-unit-range) between 0 and 1. The window is the band of material that may be selected at that moment, and it interpolates between the two states across the section.

If the lower edge lies above the upper edge, the window has negative width and describes no band at all. This is reported as a warning rather than an error because the mask can still be sampled, but the section will not do what its numbers appear to say, and since the effect is a gradual statistical one spread over a portion of the [variant](concepts/variant), it is very hard to hear as a mistake rather than as a choice.

The two ends of a section may of course cross *each other*. A window that starts high and ends low is a descent, and that is entirely normal. It is only the minimum and maximum *within* one end that must stay in order.

## How to fix it

- Swap the two numbers within the offending pair. `0.8 0.3` almost certainly wants to be `0.3 0.8`.
- Check whether you meant a descent, which is written by ordering the *start* pair above the *end* pair, each pair internally in ascending order.
- Use equal values for a window of zero width if you want the mask pinned to one point of the list at that moment; that is valid and does not warn.
