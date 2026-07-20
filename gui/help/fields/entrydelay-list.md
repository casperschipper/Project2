# Entry delay list

> The supply of time intervals between one attack and the next, in seconds. Entry points are produced by adding these up.

The entry delay is the time-lag from one entry point to the following one. The variant's [duration](fields/variant-duration) is divided into entry points by the continuous addition of entry delays, so this list is the rhythmic vocabulary of the piece in the most direct sense: everything about the pacing comes from here.

This list is the supply, not the rhythm. Which of these values a layer can use is decided by the [table](fields/entrydelay-table) and the [ensemble](fields/entrydelay-ensemble); in what succession they occur is decided by the [order](fields/entrydelay-order) principle. See [list, table, ensemble, order](concepts/list-table-ensemble-order).

## Example

```
index   0    1    2    3    4    5    6    7
value  0.1  0.2  0.3  0.4  0.5  0.6  0.7  0.8
```

An even ramp of eight values from very fast to moderately slow. This is a good neutral starting list: it lets the table carve out "fast", "moderate" and "everything" groups, and it lets [tendency](concepts/tendency) trace a continuous accelerando or ritardando because the values are in order.

A quite different list of the same length:

```
0.1  0.1  0.125  0.15  1.0  1.2  2.0  3.0
```

Here the vocabulary is bimodal — a cluster of very fast values and a cluster of slow ones, with nothing between. Under [alea](concepts/alea) the result is a music that is either rapid or static and never merely walking. The list, before any principle is applied, has already decided a great deal.

## Notes on values

- Values are in seconds. Fractions like `1/2` are accepted alongside decimals, and are written back as you typed them — the notation you choose is itself information about how you are thinking.
- The **average** of the active ensemble determines how many entry points a layer produces: the variant duration divided by that average. A list weighted toward long values therefore yields a shorter, sparser piece for the same stated duration.
- An entry delay of 0 produces a *pseudo chord* — two or more tones commencing simultaneously because no time elapsed between them. This is distinct from a chord proper, which arises from [density](concepts/density).
- Entry delay interacts directly with duration: if a tone's duration is shorter than its entry delay a *pseudo rest* appears automatically; if longer, tones overlap. See [duration relation](fields/duration-relation).

## Related

- [entry delay table](fields/entrydelay-table)
- [duration list](fields/duration-list)
- [variant duration](fields/variant-duration)
