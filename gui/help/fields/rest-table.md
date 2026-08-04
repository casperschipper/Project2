# Rest table

> Rows are groups of rest lengths; cells are positions in the [rest list](fields/rest-list).

The table plays its usual role here: it carves the rest-length list into vocabularies — a group of short lengths for brief hesitations, a group of long lengths for real breaks — and the [ensemble](fields/rest-ensemble) principle decides which group is active. See [indices](concepts/indices) for why the cells hold positions rather than values.

Unlike [entry delay](fields/entrydelay-table)'s table, the group chosen here has no effect on *how many* rests are placed — that is decided entirely by [rest mode](fields/rest-mode)'s own entry-range search. It only affects the character of whichever rests that search does end up placing.

## Example

```
index   0    1    2
value  0.5  1.0  2.0
```

```
group 0:  0 1        brief hesitations
group 1:  1 2        real breaks
group 2:  0 1 2       either
```

## Related

- [rest list](fields/rest-list)
- [rest ensemble](fields/rest-ensemble)
- [rest mode](fields/rest-mode)
