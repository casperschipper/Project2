# Instrument table

> Rows are instrument groups; cells are positions in the [instruments](fields/instruments) list. Each group is a possible instrumentation for a layer.

The table partitions your instrument list into groups. A group is an ensemble in the ordinary musical sense: a set of instruments that will play together in one [layer](concepts/layers). See [list, table, ensemble, order](concepts/list-table-ensemble-order) for how the table fits into the chain, and [indices](concepts/indices) for why cells hold positions rather than names.

The instrument table is the most consequential table in the formula, for two reasons. First, it is the only one from which several groups may be selected at once — as many as [number of instrument groups](fields/number-of-instrument-groups) asks for — so it alone determines how many layers a variant has. Second, under [combination](concepts/union-and-combination) every other parameter's group selection follows this one, which means the row numbering here becomes the organising principle of the entire formula.

## Example

Instrument list, with positions:

```
0 guitar1   1 guitar2   2 piano   3 basedrum   4 marimba
```

Table:

```
group 0:  0 1 2 3        guitars, piano, bass drum
group 1:  0               guitar1 alone
group 2:  2 3             piano and bass drum
```

Group 0 is a broad mixed ensemble. Group 1 is a solo — one instrument, fixed at six-note chords by its [chord size](fields/instrument-chordsize), so a layer built on it is a chain of chords and nothing else. Group 2 pairs a fully chromatic instrument with a percussion instrument.

With two instrument groups selected and [union](fields/union) off, a variant might set group 1 against group 2: a slow succession of guitar chords over a piano-and-drum layer. The next variant, if the ensemble principle is `series`, will pair different rows and produce a different confrontation from the same table.

Note that `marimba` (position 4) is in no group at all. It is defined, it is available, and it will never sound. That is legitimate — you can keep instruments in reserve — but it is worth checking, because an instrument left out of every group is indistinguishable from a typing error.

## Designing groups

Think of each row as a musical character, not as a subset. Ask what a layer built only on this group would sound like, and whether it can be told apart from the other rows. Rows that differ only slightly produce layers that differ only slightly, and the effort of grouping is wasted.

Repeating a position within a group weights it: `0 0 2` makes guitar1 about twice as likely as the piano under most [selection principles](concepts/selection-principles). This is a legitimate way to make one instrument the leader of an ensemble.

If any parameter uses `combination`, its table must have exactly as many rows as this one, and its row *n* should be designed to suit this table's row *n*.

## Related

- [instrument ensemble](fields/instrument-ensemble)
- [instrument order](fields/instrument-order)
- [number of instrument groups](fields/number-of-instrument-groups)
