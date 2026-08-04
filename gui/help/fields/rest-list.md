# Rest list

> The supply of possible rest lengths, in seconds — how long a silence lasts once one is placed.

REST (EMR-3 §7.4) is not a resolution step like the other five parameters: it never appears in the [hierarchy](fields/hierarchy), and it does not decide *where* a rest goes on its own. Placement is a search over the timeline everything else has already produced, configured on the [Structure](fields/rest-mode) screen. This list only supplies *how long* each placed rest lasts, once the search has found somewhere to put one — the same LIST role every other parameter's own list plays. See [list, table, ensemble, order](concepts/list-table-ensemble-order).

Which of these lengths is available for a given rest is decided by the [table](fields/rest-table) and the [ensemble](fields/rest-ensemble); in what succession they occur (across however many rests end up placed) is decided by the [order](fields/rest-order) principle.

## Example

```
index   0    1    2
value  0.5  1.0  2.0
```

A short interruption, a noticeable pause, and a real break. Under [alea](concepts/alea) the rests that do occur will vary between these in character; under [series](concepts/selection-principles) they cycle through all three before any repeats.

## Notes on values

- Values are in seconds. Fractions like `1/2` are accepted alongside decimals.
- Unlike duration or entry delay, there is no natural upper bound suggested by an instrument or an entry rate — a rest length is free-standing silence, so the vocabulary here is entirely your own rhythmic decision.
- How *many* rests actually get placed, and where, is governed entirely by [rest mode](fields/rest-mode)'s entry range — this list has no influence over that, only over how long each one turns out to be.

## Related

- [rest mode](fields/rest-mode)
- [rest table](fields/rest-table)
- [rest order](fields/rest-order)
