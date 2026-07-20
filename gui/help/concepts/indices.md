# Indices

> Tables never contain values. They contain positions into the parameter's list. This is what lets you regroup material without retyping it, and reshape material without redoing the grouping.

Each parameter has one [list](concepts/list-table-ensemble-order) — the supply of actual values — and one table whose rows are groups. The cells of the table are *elements*: index numbers naming positions in the list. An element is a magnitude chosen by a selection program, and it is only resolved against the list when it is actually needed, for a compatibility test or for the score printout.

There are three good reasons for this indirection, and they are all compositional.

**Separation of material from structure.** You can change `0.4` to `0.45` in the list, and every group naming that position follows. The architecture of the piece — which values belong together, which groups oppose which — survives a change of content. Conversely you can rewrite the table without touching a single value, exploring different partitions of the same vocabulary.

**Repetition as weighting.** An index may be named more than once inside a group, and this is deliberate. A group written `0 0 1 2` has four elements, two of which resolve to the same value, so [series](concepts/series) will produce that value twice per cycle and the others once — an exact 2:1:1 proportion built into the group's structure rather than into a separate weighting mechanism. Repetitions may also be spread across several groups.

**Selection operates on elements, not values.** The order principle selects ensemble *positions*; it does not know or care that two of them denote the same value. This is why duplicated indices weight the outcome rather than being collapsed away.

## Example

Dynamics list:

```
index   0    1   2   3    4   5    6
value  ppp  pp   p   mf   f   ff  fff
```

Table:

```
group 0:  0 1 2 3 4 5 6      everything
group 1:  2 3 4              the middle
group 2:  0 6                the extremes only
group 3:  3 3 3 4 5          mf-heavy
```

Group 2 is a two-element group whose values are as far apart as the list allows — read with `series` it alternates `ppp` and `fff` in random order, which is a very particular musical object built from nothing but two numbers. Group 3 weights `mf` three to one against `f` and `ff`.

Now suppose you decide the list should run `pppp pp p mf f ff ffff`. Every group above keeps its meaning: group 2 is still "the extremes", group 3 is still "mf-heavy". Nothing needs editing.

## 0-based and 1-based display

The engine reads and writes indices as **0-based**: the first item of a list is index 0. Many composers, and the original manual's presentation, think 1-based: the first item is 1.

The [start index](fields/start-index) setting switches how indices are *displayed* throughout this interface — in tables, in ratio weights, in sequence definitions. It changes nothing in the file: what is written out is always 0-based, because that is what the engine reads. It is a reading convention, chosen once, so that the numbers on screen match the way you count.

Set it and leave it. Changing it mid-project is harmless to the data but guarantees you will misread a table at some point.

## Related

- [list, table, ensemble, order](concepts/list-table-ensemble-order)
- [start index](fields/start-index)
- [ratio](concepts/ratio) — weights are also given per list index
