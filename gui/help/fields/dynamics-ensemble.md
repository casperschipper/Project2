# Dynamics ensemble

> Which group of the [dynamics table](fields/dynamics-table) becomes active. Normally one group per layer.

This slot answers "which group?"; the [order](fields/dynamics-order) principle answers "which value, event by event". See [list, table, ensemble, order](concepts/list-table-ensemble-order).

**Alea** — a group at random.

**Series** — groups without repetition until the table is exhausted. Successive variants systematically visit each dynamic register you have defined, which is a good way to hear what your table actually contains.

**Sequence** — the group is named explicitly and stays the same across variants.

**Combination** — the group index copies the instrument parameter's selection. The dynamics table must then have exactly as many rows as the [instrument table](fields/instrument-table). Your group-selection principle is overridden; the order principle is unaffected.

Dynamics is the parameter where combination earns its keep most obviously, because instrumental dynamic ranges differ so sharply. Pairing a soft dynamics group with a soft-capable instrument group is not a refinement — without it, a layer of marimba and bass drum asked for `ppp` produces wrong elements at nearly every event.

## Example

Dynamics table:

```
group 0:  0 1 2 3 4 5 6      full range
group 1:  2 3 4              p mf f
group 2:  0 1 2 3 4 5 6      full range
```

Instrument table:

```
group 0:  guitar1 guitar2 piano basedrum
group 1:  guitar1                          (dynamics: p mf f ppp)
group 2:  piano basedrum                   (dynamics: ppp ... fff)
```

The dynamics table has been written to match: row 1 is `p mf f`, precisely what guitar1 can do; rows 0 and 2 are the full range, which piano and bass drum can realise.

With **combination** and [union](fields/union) off, selecting instrument rows 1 and 2 gives a guitar layer confined to the middle dynamics and a piano-and-drum layer using everything from `ppp` to `fff`. Every event is playable. The dynamic differentiation between the layers is a designed feature rather than a byproduct of filtering.

With **series** instead, the guitar layer might receive dynamics group 0 and be asked for `fff` repeatedly, which it cannot play — the resulting score is full of [comments](fields/comment) and the guitar's dynamic behaviour is decided by rejection rather than by you.

## Related

- [dynamics table](fields/dynamics-table)
- [union and combination](concepts/union-and-combination)
