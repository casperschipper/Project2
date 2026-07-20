# Union and combination

> Combination decides whether the other parameters follow the instrument parameter's choice of groups. Union decides whether the resulting groups are merged into one pool or kept apart as separate layers.

These two switches control the coordination between parameters at the *group* level — the stage where ensembles are assembled from tables. See [list, table, ensemble, order](concepts/list-table-ensemble-order) for the chain they act on.

The number of instrument groups entering the ensemble is always set by [number of instrument groups](fields/number-of-instrument-groups). The two questions that remain are: do the other parameters adopt that same multiplicity (combination), and does the multiplicity produce one layer or several (union)?

**Combination** means the group indices chosen for a parameter simply copy those chosen for instrument. If the instrument ensemble principle selects table rows 1 and 3, then a combined dynamics parameter uses dynamics table rows 1 and 3 too. Its own ensemble-selection principle is overridden and no longer does anything; its *order* principle is untouched and still governs how values are drawn. A combined parameter's table must therefore have the same number of rows as the instrument table, and the interface warns if it does not.

The point of combination is guaranteeing *correspondence*. Row 1 of the instrument table might be your plucked strings, and row 1 of the dynamics table the soft dynamics they are good at; combination makes sure those two are always chosen together, rather than trusting the [hierarchy](concepts/hierarchy) to repair a bad pairing after the fact. It is the difference between designing compatible material and filtering incompatible material.

**Union** means the groups in an ensemble are treated as a single pool. One layer results, drawing from everything at once. Without union, each group stays separate and produces its own [layer](concepts/layers) with its own succession of values.

## The four cases

**Combination + union.** One layer. Each combined parameter's ensemble is built by merging the groups whose indices match the instrument selection, then treating the merge as a single pool. The full instrumental palette is available as one texture, but a statistical correlation survives the merge: values that share a group index with certain instruments are more likely to co-occur with them, because they entered the pool together. Non-combined parameters contribute one group per variant.

**Combination, no union.** One layer per selected instrument group, and each layer's other parameters come from the matching rows of their own tables. This is the most strongly differentiated case: every layer has its own instruments *and* its own durations, dynamics and articulations, chosen to suit them. If you want two simultaneous musics with distinct characters — a slow, soft, sustained layer against a fast, loud, percussive one — this is the setting.

**No combination, union.** One layer. The instrument ensemble merges however many groups were selected, but every other parameter contributes just one group. A single uniform rhythmic and dynamic vocabulary applied across the whole instrumental palette. Vocabulary changes can then only happen from variant to variant, never within one.

**No combination, no union.** One layer per instrument group, but each non-instrument parameter is assigned one group per layer independently of the instrument choice. Layers are separate, yet their materials were not designed to match — the relationships are left to chance and to the hierarchy.

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

With [number of instrument groups](fields/number-of-instrument-groups) = 2, ensemble principle `series`, combination on and union off: the program selects, say, instrument rows 1 and 2. Two layers result. Layer A is guitar1 alone, drawing dynamics only from `p mf f` — no `fff` can be requested and then rejected, because it was never in that layer's pool. Layer B is piano and bass drum with the full dynamic range. The two layers sound simultaneously and sum to the variant.

Turn union on and the same selection produces one layer: guitar1, piano and bass drum in a single stream, drawing from a merged dynamic pool that contains `p mf f` twice over and the extremes once — so the middle dynamics predominate, as a residue of the grouping.

## Notes

- Instrument itself has no combination setting. There is nothing for it to follow — it is what the others follow.
- Polyphony in the sense of simultaneous independent layers comes from *not* using union. Union always yields a single layer.
- Historically, only the instrument parameter could contribute several groups to one ensemble; combination was added later so that the other parameters could track the instrument choice.

## Related

- [layers](concepts/layers)
- [union field](fields/union)
- [hierarchy](concepts/hierarchy)
