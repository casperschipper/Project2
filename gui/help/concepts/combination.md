# Combination

> A parameter set to combination stops choosing its own group and follows the instrument parameter's choice instead. Its table must therefore line up with the instrument table, row for row.

Normally each parameter runs its own ensemble principle and picks its own group from its own table. The choices are made independently, so there is no guarantee that the dynamics group selected for a variant suits the instrument group selected alongside it. Combination removes that independence.

When a parameter is combined, the group *indices* chosen for instrument are simply copied. If the instrument ensemble principle selects table rows 1 and 3, a combined dynamics parameter uses dynamics table rows 1 and 3 too. Its own ensemble principle is overridden and no longer does anything. Its [order](selection-principles) principle is untouched and still governs how values are drawn from whatever it ends up with — combination changes *which* stockpile, never *how it is read*.

Instrument itself has no combination setting. There is nothing for it to follow; it is what the others follow.

## The 1:1 row alignment requirement

This is the part that trips people up, and it follows directly from the mechanism. If combination copies row *indices*, then row 1 of the combined parameter's table has to exist and has to mean something compatible with row 1 of the instrument table. A combined parameter's table must have **the same number of rows as the instrument table**, and those rows must correspond in intent, not merely in count. The interface warns when the counts do not match, but nothing can check the intent for you — that part is composition.

So combination changes how you write tables. Without it, each table is an independent list of useful subsets, and the rows of different parameters have nothing to do with one another. With it, the tables become **parallel columns of a single design**: row *n* of every combined table describes one coherent musical character, viewed through that parameter.

## The point of it

Combination guarantees *correspondence*. Row 1 of the instrument table might be your plucked strings; row 1 of the dynamics table, the soft dynamics they are good at; row 1 of the duration table, the short lengths a plucked note actually has. Combination makes sure those are always chosen together.

The alternative is to let the groups be chosen independently and trust the [hierarchy](hierarchy) to repair a bad pairing afterwards. It will try — but repair means rejecting values, and rejection that fails leaves a wrong element and a [comment](fields/comment) in the score. Combination is the difference between *designing compatible material* and *filtering incompatible material*. If a variant is producing comments steadily, combination is often the real fix, ahead of loosening the tables.

## Example

Instrument table:

```
row 0:  guitar1 guitar2 piano basedrum     (everyone)
row 1:  guitar1                            (one guitar)
row 2:  piano basedrum                     (keyboard and drum)
```

Dynamics table, built deliberately row for row against it:

```
row 0:  ppp pp p mf f ff fff               (the full palette)
row 1:  p mf f                             (what guitar1 can do)
row 2:  ppp pp p mf f ff fff               (piano and bass drum: everything)
```

With [number of instrument groups](fields/number-of-instrument-groups) = 2, combination on for dynamics and [union](union) off, the ensemble principle selects instrument rows 1 and 2. Two [layers](layers) result.

Layer A is `guitar1` alone, drawing dynamics only from `p mf f`. No `fff` is ever requested and then rejected, because `fff` was never in that layer's pool at all. Layer B is `piano` and `basedrum` with the full dynamic range available. Each layer is a matched set, and the score comes out clean.

Turn combination off and keep everything else. Dynamics now selects a single group per variant by its own principle — say row 0 — and *both* layers use it. Layer B is unaffected. Layer A now has `ppp` and `fff` in its pool for an instrument that cannot play them, so the hierarchy starts rejecting values and the comments begin.

## Related

- [union and combination](union-and-combination) — the fuller treatment, with all four cases
- [layers](layers)
- [union](union)
- [hierarchy](hierarchy)
- [list, table, ensemble, order](list-table-ensemble-order)
