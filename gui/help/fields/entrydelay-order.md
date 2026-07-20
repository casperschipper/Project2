# Entry delay order

> How entry delays are drawn from the active group, event by event. This is the parameter that produces the rhythm.

Once the [ensemble](fields/entrydelay-ensemble) has fixed which delays are available, the order principle decides their succession — and since entry points are formed by accumulating these values, the order principle *is* the rhythm. All six [selection principles](concepts/selection-principles) are available.

Of the five parameters, this one usually rewards the most attention. Listeners perceive rhythmic organisation more readily than dynamic or timbral organisation, so whatever structure you put here will be the structure the piece appears to have.

## Which principle

**Series** rotates through the available delays, each once per cycle. The result is irregular but statistically even — no long stretch of only fast or only slow values. A good default.

**Alea** clumps. Runs of the same delay produce accidental pulses; gaps produce accidental pauses. Considerably more unpredictable than series, and often less characterful, because the clumps are not shaped.

**Ratio** gives you a rhythmic profile: mostly one value, with others as ornament or interruption. This is the most direct way to write "a fast music with occasional long silences" without leaving the aleatoric domain.

**Group** produces metrical passages — the same delay held for several events is a pulse, and a change of delay is a change of tempo. If you want the piece to have sections rather than a uniform flow, this is the principle.

**Tendency** produces accelerando and ritardando. With the list written in order, a window travelling from the long end to the short end is a continuous acceleration across the layer; a window that starts narrow and widens is a pulse dissolving into free rhythm.

**Sequence** writes the rhythm out. A fixed cell, looped for the whole layer.

## Example

Active group `0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8`, twelve events, entry points shown as running totals.

**Ratio** with weights `1 3 1 5 2 1 1 10` (favouring `0.8` heavily, then `0.4`, then `0.2`):

```
delay   0.8  0.4  0.8  0.2  0.8  0.8  0.4  0.5  0.8  0.2  0.4  0.8
entry   0.0  0.8  1.2  2.0  2.2  3.0  3.8  4.2  4.7  5.5  5.7  6.1
```

A predominantly slow rhythm with sudden close pairs where the short delays fall. Because ratio is exhaustive over its weighted supply, the rare values `0.1`, `0.6`, `0.7` are each guaranteed to arrive once per 24 events — they are genuine events, not statistical accidents.

Compare **series** on the same group: all eight delays occur once per cycle, so every eight events cover a fixed total of 3.6 seconds. The rhythm is varied locally but perfectly regular at the level of the cycle — a periodicity you may or may not want.

## Interaction with duration

If the [duration relation](fields/duration-relation) is `equals-entry` or `shorter-than-entry`, this parameter and duration constrain each other, and which one is free depends on the [hierarchy](fields/hierarchy). With `Ent` before `Dur`, the rhythm is exactly what this principle produces and durations are fitted to it. With `Dur` before `Ent`, the durations are free and entry delays too short for them are rejected — your rhythmic design will be disturbed.

## Related

- [entry delay list](fields/entrydelay-list)
- [duration relation](fields/duration-relation)
- [selection principles](concepts/selection-principles)
