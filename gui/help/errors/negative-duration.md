# A duration is negative

One of the values in the duration list is below zero.

## Why this matters

A duration is how long a tone sounds, measured forward from its entry point. Like an [entry delay](negative-entry) it is a length of time, not a position, so it has no meaningful negative value: a tone cannot end before it begins.

Duration matters structurally as well as literally, because Project Two compares durations against entry delays. Whether a tone overlaps the next entry, ends exactly with it, or falls short of it and leaves a *pseudo rest* is decided by that comparison, and it is one of the main ways the [duration relation](concepts/duration-relation) shapes the rhythmic context. Each instrument also declares its own shortest and longest playable duration, and the list values are filtered against those. A negative value has no place anywhere in that arithmetic.

## How to fix it

- Correct the value. `0` is permitted if you want an instantaneous attack, though for most purposes a very short positive value is more musical.
- Check the sign if you wrote a fraction: `-1/8` is negative.
- If you wanted a tone to stop before the next entry point, that is what the *shorter than entry* [duration relation](concepts/duration-relation) is for, not a negative number.
