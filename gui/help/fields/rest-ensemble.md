# Rest ensemble

> Which group of the [rest table](fields/rest-table) becomes active. Normally one group per layer.

The ensemble slot answers "which group?", not "which length?" — the latter is the [order](fields/rest-order) principle's job. See [list, table, ensemble, order](concepts/list-table-ensemble-order).

Four settings, exactly as for every other parameter:

**Alea** — a group at random each time.

**Series** — groups are used without repetition until the table is exhausted, then regenerated.

**Sequence** — you name the group explicitly. The rest vocabulary is fixed across all variants while the rest of the formula continues to vary.

**Combination** — the group is not chosen at all: it copies whatever group index the instrument parameter selected for this layer. The rest table must then have as many rows as the [instrument table](fields/instrument-table), row *n* here paired with instrument row *n*.

REST is calculated and inserted independently per layer (EMR-3 §7.4), so under [union](fields/union) "none" or "common harmony" each layer draws its own group here; under "union" there is only one merged layer to begin with.

## Related

- [rest table](fields/rest-table)
- [rest mode](fields/rest-mode)
- [union and combination](concepts/union-and-combination)
