# Union

> Whether the groups selected into an ensemble are merged into one pool — giving a single layer — or kept apart, each becoming a layer of its own. When kept apart, a second question follows: does each layer get its own independent harmony, or do all of them share one continuous harmony stream?

Union is a switch with a large consequence: it decides whether your variant is one music or several musics at once — and, when it's several, whether those musics are pitched independently or speak with one shared voice.

With **union on**, the ensemble is treated as a single unit. However many groups went into it, the [selection principles](selection-principles) for the score read across the whole merged pool as if the grouping had never happened. Exactly one [layer](layers) results.

With **union off**, each group in the ensemble stays a separate stockpile. Each generates its own layer, with its own entry points, its own succession of values, and its own event count derived from its own average entry delay. The layers sound simultaneously, share the [variant duration](fields/variant-duration) and tempo, and — in the printed parts — each is written out as its own block, not interleaved line by line. Union-off itself splits into two settings, differing only in what happens to HARMONY:

- **`none`** — every parameter, HARMONY included, resolves independently per layer. [Harmony principle](fields/harmony-principle) sits wherever you placed it in the [hierarchy](hierarchy), and each layer walks its own copy of that row/matrix/chord chain on its own schedule.
- **`common-harmony`** — every parameter *except* HARMONY still resolves independently per layer, exactly as under `none`. HARMONY is forced to the very last position in the hierarchy and resolves exactly once: after every layer's rhythm is fixed, the layers are fitted together into one true chronological timeline, and a single continuous row/interval-matrix walk crosses freely between layers in that timeline's real-time order — as if one melodic line had simply been handed back and forth between the layers, rather than each layer reading its own independent copy from the top.

So: **polyphony in PROJECT TWO comes from turning union off** (either sub-setting). Union always yields a single layer, no matter how much it merged. If you want two independent simultaneous strands, `none` or `common-harmony` is the setting, and [number of instrument groups](fields/number-of-instrument-groups) is then effectively the number of strands — `common-harmony` just additionally ties their pitches to one shared thread.

## What merging does to weighting

Merging is not quite neutral. If two selected groups both name the same item, the merged pool contains it twice, and most order principles will pick it about twice as often.

This is worth exploiting rather than avoiding. The grouping you designed survives the merge as a statistical bias: values that appeared in several of the selected groups become the centre of gravity of the single layer, and values that appeared in only one become its outliers. You get a unified texture that still leans the way your tables leaned. See [indices](indices) on why repeated indices inside a group weight it.

## Example

Instrument table:

```
row 0:  guitar1 guitar2 piano basedrum
row 1:  guitar1
row 2:  piano basedrum
```

With [number of instrument groups](fields/number-of-instrument-groups) = 2 and an ensemble principle that selects rows 1 and 2:

**Union = none.** Two layers. Layer A is `guitar1` alone; layer B is `piano` and `basedrum`. Each has its own rhythm, its own reading of its dynamics, its own event count, *and* its own independent pass through the row — two distinct musics with no relationship between which pitches happen to land at the same moment. If layer A's entry delays average 0.5 s and layer B's average 0.2 s, then over 30 seconds A produces about 60 attacks and B about 150 — a sparse guitar line against a rapid piano-and-drum surface.

**Union = common-harmony.** The same two layers, the same two instrumentations, the same two event counts — but now there is only one row being walked. As guitar1's and the piano/bass-drum duo's notes interleave in performance time, the pitches form one unbroken sequence, as if a single melodic line had simply been handed back and forth between the two layers.

**Union = union.** One layer whose instrument pool is `guitar1, piano, basedrum` merged. A single stream of entry points in which any of the three may appear at any moment. Richer in variety from instant to instant, but there is only one rhythmic argument going on — the three instruments are three colours of one line, not three voices.

Note that `none` and `common-harmony` do not differ in how *much* sounds, or in the rhythm of either layer — only in whether pitch is coordinated by one shared principle across both layers, or by two running independently.

## Relation to combination

Union and [combination](combination) are independent switches, and it is easy to confuse them because both operate at the group stage.

- **Combination** is about *which* groups the non-instrument parameters use — their own choice, or the instrument parameter's.
- **Union** is about what is done with the groups once chosen — merge them, keep them apart with independent harmony, or keep them apart sharing one harmony.

The resulting cases are worked through in [union and combination](union-and-combination). The short version: combination with union off is the most strongly differentiated setting, giving each layer its own instruments *and* its own matched durations, dynamics and modes; union without combination is the most uniform, a single texture drawing on the full palette. Common-harmony sits in between on the harmony axis specifically: everything else stays as differentiated as `none` allows, but pitch is unified.

## Related

- [union and combination](union-and-combination) — the fuller treatment, with all the cases
- [layers](layers)
- [combination](combination)
- [union field](fields/union)
- [number of instrument groups](fields/number-of-instrument-groups)
- [hierarchy](hierarchy)
- [harmony principle](fields/harmony-principle)
