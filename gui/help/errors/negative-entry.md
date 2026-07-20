# An entry delay is negative

One of the values in the entry delay list is below zero. The program found a negative number where it expects a span of time.

## Why this matters

An entry delay is the time that passes between one entry point and the next one after it. Project Two builds the rhythmic context of a variant by laying entry points end to end: it draws a value from the [entry delay ensemble](concepts/list-table-ensemble-order), places the next entry that far ahead, and repeats until the [variant duration](concepts/variant) is filled. The delay is therefore a distance forward in time, never a position, and never a direction.

A negative delay would ask the next entry point to fall before the one that produced it. The chronological order of the rhythmic context would break, and the count of entry points derived from the variant duration and the average entry delay would stop being meaningful. Zero is allowed and is musically useful: two tones with a delay of 0 between them start together and form what the manual calls a *pseudo chord*. That is the intended way to write simultaneity, and it is why the floor is zero rather than some small positive number.

## How to fix it

- Correct the value in the [entry delay list](concepts/list-table-ensemble-order). If you meant simultaneity, write `0`.
- If you wrote the value as a fraction, check the sign of the numerator: `-1/4` is a negative quarter, not a quarter.
- If you were trying to make a tone *end* before the next entry, that is not an entry delay question at all. Use the [duration relation](concepts/duration-relation) instead, which lets a duration be shorter than its entry delay and so produce a rest.
