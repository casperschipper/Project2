# Instrument ensemble

> Which groups of the [instrument table](fields/instrument-table) become active for this variant. The instrument parameter is the only one that may select several groups at once.

The ensemble principle answers the question "which group?" — as opposed to the [order principle](fields/instrument-order), which answers "which instrument, event by event, from the group we have". Confusing the two is the most common source of puzzlement when learning the program; see [list, table, ensemble, order](concepts/list-table-ensemble-order).

It is applied as many times as [number of instrument groups](fields/number-of-instrument-groups) asks for. Three principles are available:

**Alea** — groups are chosen at random, with repetition allowed. Two layers may land on the same group.

**Series** — groups are chosen without repetition until all have been used, then the table is regenerated. This is usually what you want: it guarantees that successive variants work systematically through the pairings your table offers rather than returning to a favourite.

**Sequence** — you name the groups explicitly, in order. The same groups are active in every variant. This is how you pin the instrumentation down while continuing to explore the other parameters.

Instrument has no `combination` option. Combination means following the instrument parameter's group selection, and there is nothing for instrument itself to follow — it is what the others follow. The interface reports this as an error.

## Example

Instrument table with three rows; number of instrument groups = 2.

With **series**: variant 1 activates rows 0 and 1, variant 2 rows 2 and 0, variant 3 rows 1 and 2. Every pairing gets its turn. With [union](fields/union) off, each variant is a different two-layer confrontation drawn from the same table.

With **sequence 1 2**: every variant activates rows 1 and 2 — guitar1 against piano-and-drum, always. Changing the [seed](fields/seed) now varies the succession of events within those two layers but never the instrumentation. This is a good way to learn what a particular pairing is capable of.

With **alea**: variant 1 might activate rows 2 and 2 — the same group twice, producing two independent layers on the same instruments. Musically that is a canon-like doubling rather than a contrast, and if it is not what you want, use series.

## Related

- [instrument table](fields/instrument-table)
- [instrument order](fields/instrument-order)
- [union and combination](concepts/union-and-combination)
