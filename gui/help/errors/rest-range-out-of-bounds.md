# Rest entry-range is out of bounds

One of [rest mode](fields/rest-mode)'s two entry-range percentages is below `0` or above `100`.

## Why this matters

The entry range describes a window as a percentage of the variant duration — each rest's placement offset is drawn from between the two numbers, as a fraction of the whole variant. A percentage below `0` or above `100` describes a fraction of the piece that cannot exist, so no offset could ever be drawn from it.

## How to fix it

- Keep both numbers between `0` and `100`.
- If you meant a specific number of seconds rather than a proportion, convert it: a range meant to sit around 10 seconds of a 120-second variant is roughly `8` to `9`, not `8` to `9` seconds.

## Related

- [rest mode](fields/rest-mode)
- [rest entry-range is inverted](rest-range-max-below-min)
