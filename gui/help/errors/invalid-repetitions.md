# The repetition range for this group principle is not usable

The *group* [selection principle](concepts/selection-principles) has been given a repetition range with a minimum below one, or with a maximum below its minimum.

## Why this matters

The group principle works in two stages. It picks an element from the [ensemble](concepts/list-table-ensemble-order), then repeats it a number of times drawn from the repetition range, then picks again. It is how you produce material that arrives in runs, a figure stated several times over before the texture moves on, rather than a new value at every entry point. Both the choice of element and the choice of how many repeats can independently follow *alea* or *series*.

The minimum must be at least one because a repetition count of zero would mean an element is selected and then not used, which produces nothing and simply consumes selections invisibly. A maximum below the minimum describes an empty range and is reported only as a warning, because the program will sort the two bounds and carry on; but a range you did not intend is worth knowing about, since it silently changes the grain of the texture.

## How to fix it

- Set the minimum to `1` or more. `1 1` means no repetition at all, which is the same behaviour as not using the group principle.
- Set the maximum at or above the minimum. `2 4` gives runs of two to four.
- If the reversed range was a slip, correct the order rather than relying on the swap, so the formula reads as it behaves.
