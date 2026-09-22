# Duration order

> How durations are drawn from the active ensemble, event by event - more than one group under combination. All six [selection principles](concepts/selection-principles) are available.

The order principle decides the succession of tone lengths, and therefore the succession of gaps and overlaps against the [entry delays](fields/entrydelay-order). Duration is a less immediately perceptible parameter than rhythm — a listener registers *when* attacks arrive before registering how long each tone lasts — but it governs the density of the sounding texture, which is very perceptible indeed.

## Which principle

**Series** rotates through the group's durations, each once per cycle. Even coverage; the whole articulation vocabulary is audible.

**Alea** clumps, which with durations means occasional stretches of consistently long or consistently short tones arriving by accident rather than design.

**Ratio** shapes the profile: mostly short with a rare sustained tone, or the reverse. This is the principle to use when your [list](fields/duration-list) contains an outlier value that you want present but not dominant.

**Group** holds a duration for several events — a passage of uniform length, which reads as a change of articulation rather than a change of rhythm. Very effective in combination with a `series` entry delay: the pacing keeps moving while the articulation stays put.

**Tendency** produces a gradual thickening or thinning: with the list in ascending order, a window travelling upward means tones progressively outlast their entry delays and the texture accumulates over the variant. This is one of the most striking things the program can do.

**Sequence** fixes the pattern of lengths exactly.

## Example

Active group `0.1 0.2 0.3 0.5 0.8`, entry delays hovering around `0.3`, chord of one.

**Series**, one cycle:

```
duration  0.3  0.8  0.1  0.5  0.2
against   0.3  0.3  0.3  0.3  0.3
result    exact overlap  gap  overlap  gap
```

The surface alternates unpredictably between joined and detached — characteristic of series on a group that straddles the prevailing entry delay.

**Tendency**, start window at the low end, end window at the high end: the layer begins staccato, with clear silence between every tone, and ends with every tone lasting two or three times its entry delay, so the final passage is a continuously sounding mass. Nothing else changed.

## Constraints

Under the [duration relation](fields/duration-relation) `shorter-than-entry`, the principle is asked for a value not exceeding the entry delay, and offers the first admissible candidate it has. Under `equals-entry` this principle is not used at all — the duration is the entry delay. The playing instrument's [duration range](fields/instrument-durations) applies in every case.

Where no admissible value exists, a wrong element is emitted with a [comment](fields/comment).

Note that with a per-note duration mode, a separate draw is made for every note of a chord, so a chord of six consumes six values from the cycle. This makes `series` cycles complete much faster than the event count suggests.

## Related

- [duration relation](fields/duration-relation)
- [duration list](fields/duration-list)
- [selection principles](concepts/selection-principles)
