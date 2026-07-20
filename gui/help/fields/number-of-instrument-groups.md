# Number of instrument groups

> How many groups from the instrument table are selected into the ensemble for each variant. Without union, this is the number of layers.

The instrument parameter is unique in that it may contribute several groups to its ensemble at once. This field says how many. All other parameters normally contribute exactly one group — unless they are set to [combination](concepts/union-and-combination), in which case they follow the instrument parameter's selection and receive the same number.

Which groups are selected is decided by the [instrument ensemble](fields/instrument-ensemble) principle, applied this many times.

The consequence depends on [union](fields/union):

- **Union off** — one [layer](concepts/layers) per selected group. This field is the number of simultaneous strands in the variant.
- **Union on** — the selected groups are merged into one pool and one layer results. This field then controls how *broad* the instrumental palette is, not how many layers there are.

## Example

Instrument table:

```
row 0:  guitar1 guitar2 piano basedrum
row 1:  guitar1
row 2:  piano basedrum
```

Number of instrument groups = 2, ensemble principle `series`.

`Series` exhausts the three rows before repeating, so successive variants of the same formula work through the pairings systematically: rows 0+1, then 2+0, then 1+2, and so on. Each variant has two layers with a different pairing of instrumental characters.

Set the field to 1 and the variant is monophonic in the layer sense — a single strand, one instrument group. Set it to 3 and all three rows are active at once, giving three layers, one of which (row 0) contains everything and will therefore overlap with the other two.

That overlap is legal and sometimes useful, but be aware of it: two layers may draw the same instrument at the same moment, and the resulting doubling is part of the texture.

## Constraints

The value must be at least 1 and must not exceed the number of rows in the [instrument table](fields/instrument-table). Asking for more groups than exist is reported as an error.

If any parameter uses `combination`, its table must have exactly as many rows as the instrument table — see [union and combination](concepts/union-and-combination).

## Related

- [instrument table](fields/instrument-table)
- [instrument ensemble](fields/instrument-ensemble)
- [layers](concepts/layers)
