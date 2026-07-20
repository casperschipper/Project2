# Sequence

> The succession you write down, played in that order and then looped. No chance at all.

`Sequence` is the deterministic end of the [continuum](concepts/selection-principles). You give a list of positions into the stockpile; the program reads them in order, and when it reaches the end it starts again from the beginning. Nothing is shuffled and nothing is remembered beyond the current position.

This is the principle to use when a particular succession is itself the compositional idea — a rhythmic cell, an intervallic figure, a fixed alternation of two dynamics — or when you want one parameter to be a stable reference against which the aleatoric behaviour of the others becomes perceptible. A piece in which everything is aleatoric has no foreground; giving one parameter a `sequence` immediately creates one.

Be aware of the arithmetic of loops. If your sequence has 3 elements and the variant produces 100 entry points, you get 33 full cycles. If another parameter is on a `sequence` of 4, the two will drift against each other and only realign every 12 events. This phase relationship is audible and can be composed with deliberately — it is the cheapest way to get long-range structure out of short materials.

## Example

Ensemble: `0.1 0.2 0.3 0.5 0.8` (durations, positions 0–4).

Sequence `0 4 1`:

```
0.1  0.8  0.2  |  0.1  0.8  0.2  |  0.1  0.8  0.2  ...
```

Short, long, short — a recognisable gesture repeated for the whole layer. Note that `0.3` and `0.5` are in the ensemble but never sound: a sequence selects only the positions it names. That is legitimate, but if you did not intend it, you have probably confused ensemble positions with list [indices](concepts/indices).

## The two spellings

`Sequence` appears in both slots of a parameter, and the two mean different things.

- As an **order** principle it takes a list of positions and produces values in that order, as above.
- As an **ensemble** principle it names which table group or groups to activate. Here it is the most explicit possible answer to "which group?" — you are refusing to let the program decide, and the same groups will be active in every variant.

Using `sequence` in the ensemble slot is how you pin down the vocabulary while still letting the order principle vary the surface from variant to variant. That is often a good intermediate stage in learning a formula: fix the supply, explore the behaviour.

## Related

- [series](concepts/series) — free order, guaranteed coverage
- [group](concepts/group) — repetition without a fixed succession
- [list, table, ensemble, order](concepts/list-table-ensemble-order)
