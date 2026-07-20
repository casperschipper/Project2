# A tendency section has no length

A section of this [tendency](concepts/selection-principles) mask has a portion of zero or less.

## Why this matters

A tendency mask is divided into sections, and each section's portion says how much of the [variant](concepts/variant) it occupies. The portions are relative shares: two sections of `1` and `3` mean the first covers a quarter of the variant and the second three quarters. This relative form means a mask keeps its shape when you change the variant duration, which is what makes the same mask reusable across a family of variants of different lengths.

A section with a portion of zero occupies no time. Its start and end windows would have to be traversed instantaneously, so the material it describes never actually governs any part of the variant, and its presence changes nothing except to make the mask harder to read. A negative portion is worse still, since a share of time cannot be negative and the arithmetic that distributes the variant's length across sections would be corrupted by it.

## How to fix it

- Give the section a positive portion. The absolute size does not matter, only the ratio to the other sections' portions.
- Delete the section if it is not meant to be part of the shape. Removing it does not affect the others, since portions are relative and simply redistribute.
- If you were trying to write an instantaneous jump between two states, express it instead as two adjacent sections whose start and end windows meet abruptly rather than overlap.
