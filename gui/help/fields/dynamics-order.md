# Dynamics order

> How dynamics are drawn from the active ensemble, event by event - more than one group under combination. All six [selection principles](concepts/selection-principles) are available.

The order principle produces the dynamic surface of the layer. Dynamics is the parameter where the difference between the principles is most immediately audible, because a listener hears loudness change without needing to analyse anything.

## Which principle

**Series** rotates through the group's values, each once per cycle. Every dynamic is present in equal measure and no level dominates — a bright, constantly shifting surface. This is the classic Koenig sound and a sensible default.

**Alea** produces the same vocabulary with clumps: accidental runs of loud events and stretches of quiet. Less shaped, more unpredictable.

**Ratio** gives a dynamic profile with a centre. Weight `mf` heavily and the extremes lightly, and you get a music that lives in the middle and is occasionally interrupted — which reads as expressive shaping even though nothing was shaped.

**Group** holds a dynamic across several events. This is the principle that produces *terraced* dynamics: blocks at one level, then a step to another. If you want the piece to have dynamic paragraphs rather than event-by-event variation, use this.

**Tendency** produces crescendo and diminuendo across the whole layer, provided the [list](fields/dynamics-list) is written from soft to loud. A window that starts narrow at the soft end and widens as it rises gives a growth in both loudness and dynamic range — a very strong shape, and one that no combination of the other principles will produce.

**Sequence** writes the dynamic succession exactly.

## Example

Active group `p mf f ff`, twelve events.

**Series**: `mf ff p f | f p ff mf | ff mf f p` — every level four times, no level dominating, constant change.

**Group** (element `series`, repetition `series`, repetitions 2–4):

```
mf mf mf   ff   p p p p   f f
```

Four dynamic terraces in ten events. The material is identical to the series example; the music is not.

**Tendency**, window travelling from the soft end to the loud end: `p p mf p mf mf f mf f ff f ff` — a crescendo that is statistical rather than literal, so it retains local irregularity while unmistakably rising.

## Constraints

The dynamic must be playable by the instrument sounding it. With `Ins` before `Dyn` in the [hierarchy](fields/hierarchy) this is a tight constraint on the specific chosen instrument; with `Dyn` before `Ins` it is the weaker requirement that *some* instrument in the layer's pool could play it. Where no admissible value exists, a wrong element is used and marked with a [comment](fields/comment).

Note that with [dynamics mode](fields/dynamics-mode) set to per-note, a separate value is drawn for each note of a chord, so a chord of six consumes six values — `series` cycles complete far faster than the number of entry points suggests.

## Related

- [dynamics mode](fields/dynamics-mode)
- [dynamics list](fields/dynamics-list)
- [selection principles](concepts/selection-principles)
