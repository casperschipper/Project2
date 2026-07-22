# Register table

> Rows are groups of registers; cells are positions in the [register list](fields/register-list).

The table divides your registers into working groups, the same way the [dynamics table](fields/dynamics-table) and [duration table](fields/duration-table) divide theirs. A group mixing the percussion entry with pitched ranges lets a layer move between pitched and unpitched material; a group of only pitched ranges keeps a layer strictly melodic.

Because the register eventually chosen has to agree with whichever instrument plays the note - a [percussion instrument](fields/instrument-compass) can only take the percussion entry, a pitched instrument only a range overlapping its own compass - design these groups with the instrument table in view, the same way dynamics groups are designed against instrument dynamics.

## Combination

If register uses `combination`, this table must have exactly as many rows as the [instrument table](fields/instrument-table), and row *n* is paired with instrument row *n*.

## Related

- [register ensemble](fields/register-ensemble)
- [register order](fields/register-order)
- [instrument compass](fields/instrument-compass)
