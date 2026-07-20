# Start index

> A display convention: show list positions counting from 0 or from 1. It changes only what you read on screen, never what is stored or generated.

Tables in PROJECT TWO hold positions into a parameter's list rather than values — see [indices](concepts/indices). Those positions have to be counted from somewhere, and there are two conventions in circulation. The engine counts from **0**: the first item of a list is index 0. Composers, and much of the original documentation, often count from **1**.

This setting picks the convention used throughout the interface — in table cells, in [ratio](concepts/ratio) weights, in [sequence](concepts/sequence) definitions. What is written to the structure formula file is always 0-based, because that is what the engine reads. The setting is purely a reading aid.

## Example

Entry delay list `0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8`, and a group intended to hold the three shortest values.

With **start index 0** the group reads:

```
0 1 2
```

With **start index 1** the same group reads:

```
1 2 3
```

Both describe `0.1 0.2 0.3`. Both are written to the file as `0 1 2`.

## Recommendation

Choose one convention at the start of a project and leave it alone. Switching it does not corrupt anything, but it does mean that any table you sketched on paper, any note in your [comment](fields/comment) field, and any half-remembered "the loud group is 4 5 6" is now off by one. Off-by-one errors in a table are silent — they produce a perfectly valid score built from the wrong material — so this is a setting worth being boring about.

## Related

- [indices](concepts/indices)
- [list, table, ensemble, order](concepts/list-table-ensemble-order)
