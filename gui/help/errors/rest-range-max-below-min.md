# Rest entry-range is inverted

[Rest mode](fields/rest-mode)'s second entry-range percentage is below its first.

## Why this matters

The two numbers describe a window, low to high, that each rest's placement offset is drawn from. If the second is below the first there is no valid percentage between them, so no offset could ever be drawn - the search that places rests would have nothing to work with.

## How to fix it

- Swap the two numbers if they were simply entered in the wrong order.
- If you meant a single, fixed offset rather than a range, set both numbers to the same value.

## Related

- [rest mode](fields/rest-mode)
- [rest entry-range is out of bounds](rest-range-out-of-bounds)
