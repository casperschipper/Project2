# Union

> EMR-3 6.2, call 13's "s" sub-field. `union` merges all selected groups into a single pool and produces one layer. `none` and `common-harmony` both keep the groups separate, producing one layer per instrument group - they differ only in whether each layer gets its own independent harmony, or all of them share one continuous harmony stream.

This is the switch between a single stream and simultaneous strands - and, when strands are kept separate, whether those strands share one voice for pitch or each has its own.

Set to **`union`**, the groups selected for the ensemble are treated as one unit, and the [selection principles](concepts/selection-principles) for the score read across the whole merged pool regardless of how many groups went into it. Exactly one [layer](concepts/layers) results.

Set to **`none`** or **`common-harmony`**, each group in the ensemble stays a separate stockpile and generates its own layer, with its own entry points, its own succession of values, and its own event count derived from its own average entry delay. The layers sound simultaneously and share the [variant duration](fields/variant-duration) and tempo; in the printed parts each layer is still written out as its own block (headed `# layer N`), not interleaved line by line.

- **`none`** - each layer resolves entirely on its own, including HARMONY: [harmony principle](fields/harmony-principle) sits wherever you put it in the [hierarchy](fields/hierarchy), and every layer walks its own copy of that row/matrix/chord chain independently, in that layer's own internal order.
- **`common-harmony`** - every parameter *except* HARMONY still resolves independently per layer, exactly as under `none`. HARMONY is different: it is forced to the very last position in the hierarchy, and resolves exactly once, after all layers' rhythms are already fixed - the layers are fitted together into one true chronological timeline, and a single continuous row/interval-matrix walk crosses freely between layers in that timeline's real-time order. It's as if one continuous voice were momentarily split across two staves, rather than two independent voices that happen to share a row.

Polyphony in PROJECT TWO comes from `none`/`common-harmony`. `union` always yields a single layer, however many groups it merged.

## Example

Instrument table:

```
row 0:  guitar1 guitar2 piano basedrum
row 1:  guitar1
row 2:  piano basedrum
```

[Instrument groups in the ensemble](fields/number-of-instrument-groups) = 2, ensemble principle `series`, selecting rows 1 and 2.

**Union = none.** Two layers. Layer A is guitar1 alone; layer B is piano and bass drum. Each has its own rhythm and its own reading of its dynamics *and* its own independent pass through the row - two distinct musics with no relationship between which pitches happen to land at the same moment.

**Union = common-harmony.** The same two layers, the same two instrumentations - but now there is only one row being walked. As guitar1's and the piano/bass-drum duo's notes interleave in performance time, the pitches form one unbroken sequence, as if a single melodic line had simply been handed back and forth between the two layers rather than each reading its own copy from the top.

**Union = union.** One layer whose instrument pool is `guitar1, piano, basedrum` merged. A single stream of entry points in which any of the three may appear at any moment. Denser in variety, thinner in counterpoint — there is only one rhythmic argument going on.

Note a subtle consequence of merging: if two selected groups both name `piano`, the merged pool contains it twice and it will be picked roughly twice as often. Grouping survives the merge as weighting.

## Interaction with combination

Union and [combination](concepts/union-and-combination) are independent switches. Briefly:

- **combination + none** — the most differentiated: each layer has its own instruments *and* its own matched durations, dynamics and modes, *and* its own independent harmony.
- **combination + common-harmony** — each layer keeps its own instruments and matched non-harmony parameters, but pitch continuity is shared across all of them in performance-time order.
- **combination + union** — one layer, but with a statistical correlation between instruments and the parameter values that shared their group index.
- **no combination + none** — separate layers whose non-instrument vocabularies were not designed to match, each with its own harmony too.
- **no combination + common-harmony** — separate, unmatched layers as above, but still sharing one harmony stream.
- **no combination + union** — one uniform texture across the full instrumental palette.

## Related

- [layers](concepts/layers)
- [union and combination](concepts/union-and-combination)
- [number of instrument groups](fields/number-of-instrument-groups)
- [hierarchy](fields/hierarchy)
- [harmony principle](fields/harmony-principle)
