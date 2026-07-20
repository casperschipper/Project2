# Performance table

> Rows are groups of performance modes; cells are positions in the derived [performance list](fields/performance-list). Each group is an articulatory vocabulary.

The table selects and groups the modes of performance available to a layer. Since the master list is derived from the instruments, every mode here is playable by *someone* — but not by everyone, and that distinction is what makes designing these groups a real task. See [indices](concepts/indices) for why cells hold positions rather than names.

The question to ask of each row is: which instruments could realise this group? A row containing only `pizzicato` is realisable only by the piano; a row containing only `normal` is realisable by anyone. Under a [hierarchy](fields/hierarchy) beginning with `Ins`, a row whose modes are foreign to the layer's instruments produces a [comment](fields/comment) at nearly every event.

## Example

Derived list:

```
index   0        1       2          3           4
value  normal   muted   overtone1  pizzicato   bowing
```

Table:

```
group 0:  0 0 1 2 3 4      everything, with normal weighted double
group 1:  0 1 2            the guitar modes
group 2:  0                normal only
```

Group 0 is the full palette, but `normal` appears twice, so it occurs about twice as often as any other mode — a texture of ordinary playing coloured by special articulations rather than a texture in which every event is special. That weighting is doing genuine musical work: an unweighted group would make `pizzicato` as common as `normal`, which is rarely what a composer means.

Group 1 pairs naturally with an instrument group of guitars. Group 2 is the safe group — realisable by every instrument in the formula, and therefore never a source of comments. Having one such group in the table is useful when you are still exploring.

## Combination

If performance uses [combination](concepts/union-and-combination), this table must have exactly as many rows as the [instrument table](fields/instrument-table), and row *n* is paired with instrument row *n*. This is the intended way to prevent conflicts by design: if instrument row 1 is the guitars, make performance row 1 the guitar modes, and the formula will never request a `pizzicato` from a guitar in the first place.

The interface can tell you when a group includes modes that *no* instrument in the paired group can play — the clearest sign that a row needs rethinking.

## Related

- [performance ensemble](fields/performance-ensemble)
- [performance order](fields/performance-order)
- [instrument performance modes](fields/instrument-performance)
