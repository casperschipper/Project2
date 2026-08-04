# Chord principle and common-harmony union disagree

HARMONY's [CHORD principle](fields/harmony-principle) and [union](fields/union) = common-harmony can't both be active.

## Why this matters

CHORD makes HARMONY the main parameter: it decides a whole chord - tones and how many of them - before anything else can be resolved, which requires Harmony to be *first* in the [hierarchy](fields/hierarchy) (see [harmony-requires-har-first](harmony-requires-har-first)). Common-harmony (EMR-3 §6.2's "s=1") requires the opposite: Harmony resolves once, *last*, after every layer's own rhythm is already fixed and merged into one timeline (see [harmony-requires-har-last](harmony-requires-har-last)). Harmony cannot be both first and last, so the two settings are rejected together rather than leaving the hierarchy stuck between two contradictory requirements.

## How to fix it

- To keep CHORD: switch [union](fields/union) to "none" or "union" instead of common-harmony.
- To keep common-harmony: switch the harmony [principle](fields/harmony-principle) away from Chord, to Row or Interval.

## Related

- [union](fields/union)
- [harmony principle](fields/harmony-principle)
- [harmony-requires-har-first](harmony-requires-har-first)
- [harmony-requires-har-last](harmony-requires-har-last)
