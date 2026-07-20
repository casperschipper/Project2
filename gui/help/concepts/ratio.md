# Ratio

> Weighted selection: each element gets a factor saying how often it may be drawn before the supply is exhausted and regenerated. Weight 0 blocks an element entirely.

`Ratio` lets you control *proportions* without controlling *succession*. You state, for each element of the parameter's list, a small whole number. That number is how many copies of the element go into the working supply. The supply is then shuffled and consumed; when it is empty, both the supply and the factors are regenerated automatically.

This means `ratio` is closer to [series](concepts/series) than to [alea](concepts/alea). It is not an independent weighted coin-toss at each event — it is an exhaustive pass over a weighted multiset. Over one complete cycle the proportions come out exactly as written; within the cycle the order is free. The practical benefit is that the intended balance is audible immediately rather than only statistically, over hundreds of events.

Musically, `ratio` is how you build a *hierarchy of material* inside a single group: a primary value, a secondary one, and a rarity that colours the texture when it appears. It is the principle for "mostly this, sometimes that, and once in a while something surprising".

## Example

Entry delay list:

```
index   0    1    2    3    4    5    6    7
value  0.1  0.2  0.3  0.4  0.5  0.6  0.7  0.8
```

Weights `1 3 1 5 2 1 1 10`. The working supply for one cycle contains 24 elements: one `0.1`, three `0.2`, one `0.3`, five `0.4`, two `0.5`, one each of `0.6` and `0.7`, and ten `0.8`. Shuffled, a cycle might begin

```
0.8  0.4  0.8  0.2  0.8  0.8  0.4  0.5  0.8  0.2  0.4  0.8 ...
```

Long delays dominate, medium ones punctuate, and `0.1`, `0.6`, `0.7` are single events per cycle — genuine rarities. Because the cycle is exhaustive, each of those rarities *will* occur exactly once per 24 events; it cannot vanish the way it might under `alea`.

## Weight 0

Setting a factor to 0 removes the element from the supply. This is a legitimate way to silence a list item temporarily while you experiment, without deleting it from the list or editing every table group that names it. But note the consequence: if every element of the currently active group has weight 0, the parameter has nothing to draw and the group can never produce a value. The interface warns about this — every index reachable through a table group needs a nonzero weight somewhere.

## Where it can be used

The manual is explicit that `ratio` applies to the ensemble, that is, to the *order* slot — drawing values from the active group. It is not available for choosing which table group becomes active; use `alea`, `series` or `sequence` there. See [list, table, ensemble, order](concepts/list-table-ensemble-order).

If a list item appears more than once in the ensemble, its factor is counted for each appearance, so repeated [indices](concepts/indices) in a table group multiply with the ratio weight rather than replacing it.

## Related

- [series](concepts/series) — equal weights, same exhaustive behaviour
- [alea](concepts/alea) — no weights, no memory
- [selection principles](concepts/selection-principles)
