# List, Table, Ensemble, Order

> Every parameter in PROJECT TWO passes through the same four stages: you supply values (list), you group them (table), the program picks which group is active (ensemble), and a selection principle draws from that group in time (order).

This chain is the single most important idea in the program. Once you can see it, every parameter page in this interface looks the same: entry delay, duration, dynamics, performance and instrument all work identically. Only the kind of value differs.

The reason for the detour through indices and groups is compositional, not technical. Koenig wanted you to write down your whole vocabulary once — every duration you might use in the piece — and then, without retyping anything, describe *sub-vocabularies* and let the program decide which sub-vocabulary is in force. A variant is not "the notes you chose". It is one reading of a set of decisions about supply, grouping and order.

## The four stages

**LIST — the supply.** A flat list of the actual values: `0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8` seconds of entry delay; `ppp pp p mf f ff fff`; your five instruments. This is the complete stockpile for the piece. An item in the list will only be heard if some group names it *and* that group is selected. Writing a value into the list is a possibility, not a commitment.

**TABLE — the groups.** Each row of the table is a *group*: a subset of the list, written as [indices](concepts/indices), never as values. A group is a musical character — "the short delays", "the loud end", "the plucked instruments". An index may appear more than once inside a group, which weights it: a group `0 0 1` will produce the first item about twice as often as the second under most order principles. If you do not want groups at all, make one row containing every index.

**ENSEMBLE — which group is active.** For a given layer, one group is chosen from the table and copied into the ensemble. The choice is itself made by a selection principle — `alea`, `series` or `sequence` — so successive variants can automatically work from different vocabularies. Under [combination](concepts/union-and-combination) several groups may enter the ensemble at once, and the instrument parameter always contributes as many groups as [number of instrument groups](fields/number-of-instrument-groups) asks for.

**ORDER — the values in time.** Finally, a second selection principle runs over the ensemble and produces the actual sequence of values for the score. This is where `alea`, `series`, `ratio`, `group`, `tendency` and `sequence` do their real musical work: same supply, radically different surface. See [selection principles](concepts/selection-principles).

So each parameter carries **two** principles: one for the ensemble (choose a group), one for the order (choose values). They are independent, and confusing them is the most common beginner's error.

## Example

Entry delay, worked through end to end.

List (eight values, index shown above):

```
index   0    1    2    3    4    5    6    7
value  0.1  0.2  0.3  0.4  0.5  0.6  0.7  0.8
```

Table (three groups):

```
group 1:  0 1 2                    "fast"
group 2:  3 4 5                    "moderate"
group 3:  0 1 2 3 4 5 6 7          "everything"
```

Ensemble principle: `series`. Order principle: `series`.

For this variant the ensemble principle picks group 2. The ensemble is now `3 4 5`, i.e. the values `0.4 0.5 0.6`. Nothing else in the list can occur in this layer — `0.1` is in the list, is named in two groups, and will still not be heard, because its group is not the active one.

The order principle now draws from `0.4 0.5 0.6` with `series`: it exhausts all three before repeating any, then reshuffles. A plausible output is

```
0.5  0.4  0.6  |  0.6  0.5  0.4  |  0.4  0.6  0.5  ...
```

Entry points accumulate by addition, so the score begins at 0.0, 0.5, 0.9, 1.5, 2.1 … The number of entry points is estimated from [variant duration](fields/variant-duration) divided by the average entry delay of the ensemble — which is why changing the ensemble changes not only the character but the *density in time* of the variant.

Now change one thing. Leave everything else and set the order principle to `ratio` with weights favouring `0.6`. Same list, same table, same active group — but the moderate delays now lean long, and the piece breathes differently. That separation of *supply* from *behaviour* is what the chain buys you.

## Why indices, not values

Because the table is about structure, not content. You can rewrite `0.4` to `0.45` in the list and every group that names index 3 follows automatically; the shape of the piece survives a change of material. See [indices](concepts/indices).

## Where to go next

- [selection principles](concepts/selection-principles) — the six behaviours
- [layers](concepts/layers) — what happens when several groups are active at once
- [hierarchy](concepts/hierarchy) — how parameters constrain each other
- [union and combination](concepts/union-and-combination) — coupling group choice across parameters
