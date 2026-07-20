# Duration table

> Rows are groups of durations; cells are positions in the [duration list](fields/duration-list). Each group is an articulation vocabulary.

Grouping durations is how you separate registers of articulation: a group of short values is a detached, pointillistic layer; a group of long values a sustained one; a group mixing the two a layer whose texture is inherently unstable. Which group becomes active is decided by the [ensemble](fields/duration-ensemble) principle; see [indices](concepts/indices) for why cells hold positions.

The decisive question when designing these groups is how the durations in each compare with the [entry delays](fields/entrydelay-table) that will be active alongside them. A group whose durations are all shorter than the prevailing entry delays gives silence between every tone. A group whose durations all exceed them gives continuous accumulation. Groups that straddle the boundary give the most varied surface, because whether a gap or an overlap appears depends on which pair of values happens to meet.

## Example

List:

```
index   0    1    2    3    4    5
value  0.1  0.2  0.3  0.5  0.8  5.0
```

Table:

```
group 0:  0 1 2 3 4          short to long, no extremes
group 1:  2 3 4              the sustaining middle
group 2:  0 1 2              short only
```

Note that `5.0` (position 5) appears in no group. It is in the list and cannot occur — deliberately held in reserve, and available the moment you add it to a group. Keeping an extreme value out of every group while you work on the rest of the formula is a good habit; adding it later is a single edit.

Against entry delays around `0.2`, group 2 gives a music in which every tone releases before the next arrives: dry, articulated, with audible silence. Group 1 gives constant overlap — nothing ever stops before something else begins — and the same rhythm sounds legato and thick. Same entry delays, same [order](fields/duration-order) principle, entirely different music.

## Combination

If duration is set to [combination](concepts/union-and-combination), this table must have exactly as many rows as the [instrument table](fields/instrument-table), and row *n* is paired with instrument row *n*. This is the intended way to respect instrumental reality: give a percussion group a table row of short durations and a sustaining group a row of long ones, and the formula will never ask the bass drum for a five-second tone in the first place — rather than asking and having the request rejected with a [comment](fields/comment).

## Related

- [duration ensemble](fields/duration-ensemble)
- [duration order](fields/duration-order)
- [instrument durations](fields/instrument-durations)
