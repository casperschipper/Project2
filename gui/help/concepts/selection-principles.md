# Selection principles

> A selection principle is a rule for drawing elements out of a stockpile. The stockpile is fixed; the principle decides the behaviour in time.

PROJECT TWO offers six: **alea**, **series**, **sequence**, **ratio**, **group** and **tendency**. They are used in two places, and it is worth being clear which is which. The *ensemble* slot of a parameter uses a principle to choose which table group becomes active (only `alea`, `series` and `sequence` are available there, plus `combination`). The *order* slot uses a principle to draw the actual values from the active group — all six are available. See [list, table, ensemble, order](concepts/list-table-ensemble-order).

The set is not arbitrary. It lays out a continuum from the fully aleatoric to the fully determined, which is the axis Koenig's work is organised around. At one end you specify only the supply and let chance do everything; at the other you specify the exact succession and chance does nothing. The interesting positions are in between, and that is where most of the composing happens.

## The continuum

```
aleatoric  <------------------------------------------------>  determined

  alea      ratio      series      group      tendency     sequence
   |          |          |           |            |            |
 free      weighted   exhaustive  repetition   directed     fixed
 choice    freedom    permutation  imposed      drift       order
```

- **[alea](concepts/alea)** — free random choice, repetitions allowed. Maximum unpredictability; the statistical profile is flat and only emerges over many events.
- **[ratio](concepts/ratio)** — random choice with a weight per element. You control the *proportions* without controlling the succession. Weight 0 blocks an element entirely.
- **[series](concepts/series)** — random, but nothing repeats until everything has appeared. The supply is used up, then regenerated. Local variety is guaranteed; global order is not.
- **[group](concepts/group)** — deliberate immediate repetition: pick a value, repeat it n times, pick another. This is how you get sustained registers, ostinato-like fields, or blocks of one dynamic.
- **[tendency](concepts/tendency)** — a moving window over the ensemble that travels from one region to another across the variant. Directional processes: getting faster, getting louder, opening out from a narrow band.
- **[sequence](concepts/sequence)** — the succession you wrote, looped. No chance at all.

## Choosing one

Ask what you want to be true of the *result*, not of the process.

- "I want all of these to occur, roughly evenly, but I don't care in what order" → **series**.
- "I want mostly short values with occasional long ones" → **ratio**.
- "I want the texture to thin out over the piece" → **tendency**.
- "I want recognisable repetition, blocks rather than a spray" → **group**.
- "I want a specific rhythm of values" → **sequence**.
- "I want no constraint whatever" → **alea**.

A useful working habit: start with `series` almost everywhere. It is the most neutral principle that still guarantees your material is actually used, and it makes the effect of your lists and tables audible. Then replace one parameter's principle at a time and listen to what that single change does. Setting six parameters to six different exotic principles at once teaches you nothing, because you cannot attribute what you hear.

## Example

Ensemble `mf f ff` (dynamics), 12 events.

| principle | a plausible output |
|---|---|
| alea | `f ff f f mf ff ff f mf mf f ff` |
| ratio 1:1:6 | `ff ff f ff mf ff ff ff f ff ff mf` |
| series | `f mf ff · ff f mf · mf ff f · f ff mf` |
| group (2–3 reps) | `f f f mf mf ff ff ff mf mf f f` |
| tendency (low→high) | `mf mf mf f mf f f f ff f ff ff` |
| sequence `mf ff f` | `mf ff f mf ff f mf ff f mf ff f` |

Same three values in every row. The material is identical; only the behaviour differs, and the musical result is not remotely the same.

## Interaction with hierarchy

A principle does not always get its first choice. If a parameter earlier in the [hierarchy](concepts/hierarchy) has already fixed something incompatible — a dynamic the chosen instrument cannot play, a duration longer than the entry delay under `shorter-than-entry` — the principle is asked for a value satisfying a predicate. It will offer the first admissible candidate it has. If no candidate is admissible it still yields a value, marked as a *wrong element*, and the score carries a [comment](fields/comment) at that point. Frequent comments are a signal that your ensembles are not compatible with each other, not that the program has failed.
