# Union

> `union` merges all selected groups into a single pool and produces one layer. `none` keeps the groups separate and produces one layer per instrument group.

This is the switch between a single stream and simultaneous strands. Set to `union`, the groups selected for the ensemble are treated as one unit, and the [selection principles](concepts/selection-principles) for the score read across the whole merged pool regardless of how many groups went into it. Exactly one [layer](concepts/layers) results.

Set to `none`, each group in the ensemble stays a separate stockpile and generates its own layer, with its own entry points, its own succession of values, and its own event count derived from its own average entry delay. The layers sound simultaneously and share the [variant duration](fields/variant-duration) and tempo; in the printed parts they are merged into chronological order.

Polyphony in PROJECT TWO comes from `none`. Union always yields a single layer, however many groups it merged.

## Example

Instrument table:

```
row 0:  guitar1 guitar2 piano basedrum
row 1:  guitar1
row 2:  piano basedrum
```

[Number of instrument groups](fields/number-of-instrument-groups) = 2, ensemble principle `series`, selecting rows 1 and 2.

**Union = none.** Two layers. Layer A is guitar1 alone; layer B is piano and bass drum. Each has its own rhythm and its own reading of its dynamics. What you hear is a duet of two distinct musics.

**Union = union.** One layer whose instrument pool is `guitar1, piano, basedrum` merged. A single stream of entry points in which any of the three may appear at any moment. Denser in variety, thinner in counterpoint — there is only one rhythmic argument going on.

Note a subtle consequence of merging: if two selected groups both name `piano`, the merged pool contains it twice and it will be picked roughly twice as often. Grouping survives the merge as weighting.

## Interaction with combination

Union and [combination](concepts/union-and-combination) are independent switches, giving four cases. Briefly:

- **combination + none** — the most differentiated: each layer has its own instruments *and* its own matched durations, dynamics and modes.
- **combination + union** — one layer, but with a statistical correlation between instruments and the parameter values that shared their group index.
- **no combination + none** — separate layers whose non-instrument vocabularies were not designed to match.
- **no combination + union** — one uniform texture across the full instrumental palette.

## Related

- [layers](concepts/layers)
- [union and combination](concepts/union-and-combination)
- [number of instrument groups](fields/number-of-instrument-groups)
