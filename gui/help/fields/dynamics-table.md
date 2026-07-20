# Dynamics table

> Rows are groups of dynamics; cells are positions in the [dynamics list](fields/dynamics-list). Each group is a dynamic register a layer can inhabit.

The table divides your intensities into working vocabularies. A group of soft values makes a quiet layer; a group of the extremes only makes a layer of violent contrasts; the full list makes a layer that can go anywhere. Which group is active is decided by the [ensemble](fields/dynamics-ensemble) principle. See [indices](concepts/indices) for why cells hold positions.

Because dynamics are constrained by the playing instrument's own [dynamic range](fields/instrument-dynamics), the design of these groups should be done with the [instrument table](fields/instrument-table) in view. A dynamics group and an instrument group that do not intersect will produce nothing but [comments](fields/comment).

## Example

List:

```
index   0    1    2    3    4    5    6
value  ppp   pp   p    mf   f    ff  fff
```

Table:

```
group 0:  0 1 2 3 4 5 6      the full range
group 1:  2 3 4              p, mf, f - the middle
group 2:  0 6                ppp and fff only
```

Group 1 is a layer with no extremes: everything happens in a moderate band, and dynamic change is a matter of shading. Group 2 is the opposite — every event is either as soft or as loud as the piece allows, with nothing between. Under [series](concepts/series) group 2 alternates the two in random order, which is a striking and very simple musical object built from two numbers.

Now check group 2 against the instruments. `guitar2` has no `ppp` and no `fff`; `marimba` has no `ppp`. If group 2 is active in a layer whose instruments are `guitar1, guitar2`, then `fff` is unplayable by either and `ppp` only by one — most events will be wrong elements. Either restrict that layer's instruments or, better, use [combination](concepts/union-and-combination) so that dynamics group 2 is only ever paired with an instrument group that can realise it.

## Weighting

Repeating a position within a group weights it. `3 3 3 0 6` is a group centred on `mf` with occasional excursions to both extremes — a dynamic profile with a home and two exceptions, which is much closer to how dynamics behave in most music than an even distribution.

## Combination

If dynamics uses `combination`, this table must have exactly as many rows as the [instrument table](fields/instrument-table), and row *n* is paired with instrument row *n*. Design row *n* here to be playable by the instruments in instrument row *n*, and the conflict problem disappears by construction.

## Related

- [dynamics ensemble](fields/dynamics-ensemble)
- [dynamics order](fields/dynamics-order)
- [instrument dynamics](fields/instrument-dynamics)
