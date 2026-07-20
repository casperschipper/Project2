# Entry delay ensemble

> Which group of the [entry delay table](fields/entrydelay-table) becomes active. Normally one group per layer.

The ensemble slot answers "which group?", not "which value?" — the latter is the [order](fields/entrydelay-order) principle's job. See [list, table, ensemble, order](concepts/list-table-ensemble-order).

Four settings:

**Alea** — a group at random each time.

**Series** — groups are used without repetition until the table is exhausted, then regenerated. Successive variants systematically work through the rhythmic characters your table offers, which is usually what you want when exploring a formula.

**Sequence** — you name the group explicitly. The rhythmic vocabulary is fixed across all variants while the rest of the formula continues to vary.

**Combination** — the group is not chosen at all: it copies whatever group index the instrument parameter selected. The entry delay table must then have as many rows as the [instrument table](fields/instrument-table), and row *n* here is paired with instrument row *n*. Your own group-selection principle is overridden; the [order](fields/entrydelay-order) principle is unaffected.

## Example

Entry delay table:

```
group 0:  0 1 2              fast
group 1:  3 4 5              moderate
group 2:  0 1 2 3 4 5 6 7    everything
```

Instrument table:

```
group 0:  guitar1 guitar2 piano basedrum
group 1:  guitar1
group 2:  piano basedrum
```

With **combination** and [union](fields/union) off, the instrument ensemble selects rows 1 and 2. Layer A is guitar1 with the *moderate* delays; layer B is piano and bass drum with *everything*. The pairing is guaranteed, not hoped for: a solo guitar layer that moves steadily against a percussion layer that ranges freely.

Now switch to **series**. The two layers each receive whichever group the series happens to be offering — layer A might get the fast delays and layer B the moderate ones, reversing the intended characters. Both variants are valid music; only one of them is the one you designed. That is precisely the difference combination exists to make.

## Related

- [entry delay table](fields/entrydelay-table)
- [union and combination](concepts/union-and-combination)
