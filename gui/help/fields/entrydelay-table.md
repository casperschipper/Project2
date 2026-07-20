# Entry delay table

> Rows are groups of entry delays; cells are positions in the [entry delay list](fields/entrydelay-list). Each group is a rhythmic vocabulary a layer might work from.

The table carves your list of delays into characters. A group of short values is a fast layer; a group of long values a sparse one; a group spanning the whole list a layer that can be either. Which group becomes active is decided by the [ensemble](fields/entrydelay-ensemble) principle. See [indices](concepts/indices) for why the cells hold positions rather than values.

Grouping entry delays has a consequence the other parameters do not have: because the number of entry points in a layer is estimated from the *average* delay of the active group, choosing a group changes not only the character of the rhythm but the number of events in the layer. Two layers on different groups over the same 30 seconds will have quite different event counts. This is the main mechanism for rhythmic differentiation between [layers](concepts/layers).

## Example

List:

```
index   0    1    2    3    4    5    6    7
value  0.1  0.2  0.3  0.4  0.5  0.6  0.7  0.8
```

Table:

```
group 0:  0 1 2                     fast:      average 0.2
group 1:  3 4 5                     moderate:  average 0.5
group 2:  0 1 2 3 4 5 6 7           everything: average 0.45
```

Over a 30-second variant: group 0 produces about 150 entry points, group 1 about 60, group 2 about 66. Groups 1 and 2 have similar event counts but sound completely different — group 1 is a steady walk within a narrow band, group 2 ranges from rapid to slow and is far more irregular.

With [union](fields/union) off and two layers active, setting group 0 against group 1 gives a fast layer and a slow layer running concurrently: the clearest kind of rhythmic counterpoint the program offers.

## Designing groups

- **Contrast in average, not just in content.** Two groups with the same average will produce layers of the same density, however differently they are spelled.
- **Repeated positions weight the group.** `0 0 0 5` is a fast group with an occasional long value — a pulse with interruptions, which is a very different object from `0 5` even though the same two values are involved.
- **Order the cells deliberately if you plan to use [tendency](concepts/tendency)**, which reads the group positionally.

## Combination

If entry delay is set to [combination](concepts/union-and-combination), this table must have exactly as many rows as the [instrument table](fields/instrument-table), and row *n* here will always be paired with instrument row *n*. That is how you give each instrument group its own characteristic pacing.

## Related

- [entry delay ensemble](fields/entrydelay-ensemble)
- [entry delay order](fields/entrydelay-order)
- [layers](concepts/layers)
