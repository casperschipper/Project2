# Performance ensemble

> Which group of the [performance table](fields/performance-table) becomes active. Normally one group per layer.

This slot answers "which group?"; the [order](fields/performance-order) principle answers "which mode, event by event". See [list, table, ensemble, order](concepts/list-table-ensemble-order).

**Alea** — a group at random.

**Series** — groups without repetition until the table is exhausted, then regenerated. Successive variants work through the articulatory vocabularies you have defined.

**Sequence** — the group is named explicitly and is the same in every variant. Useful while you are still deciding what the other parameters should do: fix the articulation, vary everything else.

**Combination** — the group index copies the instrument parameter's selection. The performance table must then have exactly as many rows as the [instrument table](fields/instrument-table). Your group-selection principle is overridden; the order principle continues to apply.

## Example

Performance table:

```
group 0:  0 0 1 2 3 4      everything (normal weighted double)
group 1:  0 1 2            normal, muted, overtone1
group 2:  0                normal only
```

Instrument table:

```
group 0:  guitar1 guitar2 piano basedrum
group 1:  guitar1                          (normal, muted, overtone1)
group 2:  piano basedrum                   (normal, pizzicato / normal, bowing)
```

The performance table has been written row for row against the instrument table. Row 1 is exactly guitar1's mode set; row 2 is `normal`, which both the piano and the bass drum can play. Row 0 is the full palette for the mixed group.

With **combination** and [union](fields/union) off, selecting instrument rows 1 and 2 gives a guitar layer cycling through its three idiomatic modes and a piano-and-drum layer playing normally throughout. Every event is realisable.

With **sequence 0** — forcing the full palette on both layers — the guitar layer will be asked for `pizzicato` and `bowing` it cannot play, and the drum layer for `muted` and `overtone1` it cannot play. The score fills with [comments](fields/comment), and the articulation that survives is whatever the filtering left behind rather than what you specified.

Note that row 2 above could have been written more ambitiously as `0 3 4` — normal, pizzicato, bowing — since between them the piano and bass drum command all three. Under a hierarchy beginning with `Ins` this works, because the mode is chosen after the instrument is known and is restricted to that instrument's set. It is a good illustration of a group being valid for a *group* of instruments without being valid for each of them individually.

## Related

- [performance table](fields/performance-table)
- [union and combination](concepts/union-and-combination)
