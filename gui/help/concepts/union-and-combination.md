# Union and combination

> Combination decides whether the other parameters follow the instrument parameter's choice of groups. Union decides whether the resulting groups are merged into one pool, kept apart as separate layers with independent harmony, or kept apart as separate layers sharing one harmony stream.

These two switches control the coordination between parameters at the *group* level — the stage where ensembles are assembled from tables. See [list, table, ensemble, order](concepts/list-table-ensemble-order) for the chain they act on.

The number of instrument groups entering the ensemble is always set by [number of instrument groups](fields/number-of-instrument-groups). The two questions that remain are: do the other parameters adopt that same multiplicity (combination), and what happens to the resulting groups — merged into one layer, kept apart with each layer pitched on its own, or kept apart but pitched from one shared thread (union)?

**Combination** means the group indices chosen for a parameter simply copy those chosen for instrument. If the instrument ensemble principle selects table rows 1 and 3, then a combined dynamics parameter uses dynamics table rows 1 and 3 too. Its own ensemble-selection principle is overridden and no longer does anything; its *order* principle is untouched and still governs how values are drawn. A combined parameter's table must therefore have the same number of rows as the instrument table, and the interface warns if it does not.

The point of combination is guaranteeing *correspondence*. Row 1 of the instrument table might be your plucked strings, and row 1 of the dynamics table the soft dynamics they are good at; combination makes sure those two are always chosen together, rather than trusting the [hierarchy](concepts/hierarchy) to repair a bad pairing after the fact. It is the difference between designing compatible material and filtering incompatible material.

**Union** means the groups in an ensemble are treated as a single pool. One layer results, drawing from everything at once. Without union, each group stays separate and produces its own [layer](concepts/layers) with its own succession of values — and there are two ways for those separate layers to be pitched, `none` (each layer's own independent [harmony](fields/harmony-principle)) and `common-harmony` (one harmony stream shared across all of them, walked in the true performance-time order the layers interleave in). Combination is entirely orthogonal to which of the three you pick: it governs whether each layer's *non-harmony* materials (durations, dynamics, articulations) are matched to its instruments, regardless of how — or whether — pitch is shared between layers.

## The cases

**With combination:**

- **Union.** One layer. Each combined parameter's ensemble is built by merging the groups whose indices match the instrument selection, then treating the merge as a single pool. The full instrumental palette is available as one texture, but a statistical correlation survives the merge: values that share a group index with certain instruments are more likely to co-occur with them, because they entered the pool together. Non-combined parameters contribute one group per variant.
- **Common-harmony.** One layer per selected instrument group, each with its own matched durations, dynamics and articulations — as differentiated as the "no union" case below in every respect except one: all layers draw their pitches from a single shared row/matrix/chord stream, walked in the true performance-time order the layers' notes interleave in, rather than each layer reading its own independent copy.
- **No union (`none`).** One layer per selected instrument group, and each layer's other parameters come from the matching rows of their own tables. This is the most strongly differentiated case: every layer has its own instruments *and* its own durations, dynamics and articulations *and* its own independent harmony, chosen to suit it. If you want two simultaneous musics with distinct characters — a slow, soft, sustained layer against a fast, loud, percussive one, each with its own unrelated pitch material — this is the setting.

**Without combination:**

- **Union.** One layer. The instrument ensemble merges however many groups were selected, but every other parameter contributes just one group. A single uniform rhythmic and dynamic vocabulary applied across the whole instrumental palette. Vocabulary changes can then only happen from variant to variant, never within one.
- **Common-harmony.** One layer per instrument group, but each non-instrument parameter is assigned one group per layer independently of the instrument choice — the layers' rhythmic and dynamic vocabularies were not designed to match. Harmony, however, *is* shared: one row/matrix/chord stream, walked across all layers in true performance-time order.
- **No union (`none`).** One layer per instrument group, but each non-instrument parameter is assigned one group per layer independently of the instrument choice. Layers are separate, yet their materials were not designed to match — the relationships, harmony included, are left to chance and to the hierarchy.

## Example

Instrument table:

```
row 0:  guitar1 guitar2 piano basedrum
row 1:  guitar1
row 2:  piano basedrum
```

Dynamics table, deliberately built to match row for row:

```
row 0:  ppp pp p mf f ff fff        (the full palette)
row 1:  p mf f                      (what guitar1 can do)
row 2:  ppp pp p mf f ff fff        (piano and bass drum: everything)
```

With [number of instrument groups](fields/number-of-instrument-groups) = 2, ensemble principle `series`, combination on and union set to `none`: the program selects, say, instrument rows 1 and 2. Two layers result. Layer A is guitar1 alone, drawing dynamics only from `p mf f` — no `fff` can be requested and then rejected, because it was never in that layer's pool. Layer B is piano and bass drum with the full dynamic range. The two layers sound simultaneously and sum to the variant, each with its own unrelated harmony.

Switch union to `common-harmony` and change nothing else: the same two layers, the same two dynamics pools — but now guitar1's notes and the piano/bass-drum duo's notes are drawn from one shared row, interleaved in real performance time rather than each layer reading its own copy from the start.

Turn union to `union` instead and the same selection produces one layer: guitar1, piano and bass drum in a single stream, drawing from a merged dynamic pool that contains `p mf f` twice over and the extremes once — so the middle dynamics predominate, as a residue of the grouping.

## Notes

- Instrument itself has no combination setting. There is nothing for it to follow — it is what the others follow.
- Polyphony in the sense of simultaneous independent layers comes from *not* using union — `none` and `common-harmony` both give it; they differ only in whether pitch is one of the independent things. Union always yields a single layer.
- Historically, only the instrument parameter could contribute several groups to one ensemble; combination was added later so that the other parameters could track the instrument choice.

## Related

- [layers](concepts/layers)
- [union field](fields/union)
- [hierarchy](concepts/hierarchy)
- [harmony principle](fields/harmony-principle)
