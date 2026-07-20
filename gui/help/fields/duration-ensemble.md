# Duration ensemble

> Which group of the [duration table](fields/duration-table) becomes active. Normally one group per layer.

This slot answers "which group?"; the [order](fields/duration-order) principle answers "which value, event by event". See [list, table, ensemble, order](concepts/list-table-ensemble-order).

**Alea** — a group at random.

**Series** — groups without repetition until the table is exhausted, then regenerated. Successive variants work systematically through your articulation vocabularies.

**Sequence** — the group is named explicitly and is the same in every variant.

**Combination** — the group index copies the instrument parameter's selection. The duration table must then have as many rows as the [instrument table](fields/instrument-table). Your own group-selection principle is overridden; the order principle continues to apply.

## Example

Duration table:

```
group 0:  0 1 2 3 4      0.1 to 0.8
group 1:  2 3 4          0.3 to 0.8, sustaining
group 2:  0 1 2          0.1 to 0.3, short
```

Instrument table:

```
group 0:  guitar1 guitar2 piano basedrum
group 1:  guitar1
group 2:  piano basedrum
```

With **combination** and [union](fields/union) off, instrument rows 1 and 2 are selected. Layer A — guitar1 — draws from duration group 1, so its six-note chords sustain and overlap. Layer B — piano and bass drum — draws from group 2 and is uniformly short and dry. The two layers have distinct articulations because you paired them, not because chance obliged.

Without combination, both layers would draw from whatever single group the ensemble principle produced, and the guitar chords and the drum strokes would share one duration vocabulary. That is not wrong — it is the sound of a homogeneous articulation across a heterogeneous ensemble — but it is a different piece.

## A note on the hierarchy

Whichever group becomes active, its values are still subject to the [duration relation](fields/duration-relation) and to the playing instrument's own [duration range](fields/instrument-durations). A group of long durations selected for a layer of short-lived percussion will generate a steady stream of [comments](fields/comment). Combination is the structural fix for exactly this.

## Related

- [duration table](fields/duration-table)
- [union and combination](concepts/union-and-combination)
