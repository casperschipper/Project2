# This parameter's table has no groups

The [table](concepts/list-table-ensemble-order) for this parameter contains no rows at all.

## Why this matters

The table is the middle stage of the [list, table, ensemble chain](concepts/list-table-ensemble-order), and it is not optional. A list is only a stockpile of possibilities; the manual is explicit that a list item can occur in a variant only if its index is named in the table *and* the group containing that index is selected for the ensemble. Nothing reaches the score by being in a list alone.

The table's job is to arrange the list into groups, so that the [ensemble](concepts/list-table-ensemble-order) can be assembled from whole groups rather than from loose items. Groups are how you express that certain material belongs together: these instruments with these dynamics, that register with that articulation. With no groups at all there is nothing to select, so this parameter can never contribute a value and no tone can be completed.

If your piece does not need grouping for this parameter, that is fine, but the table still has to exist. The manual's own advice is that when no groups are to be formed, it is sufficient to name every list index once, in a single group.

## How to fix it

- Add one group containing every index of the list, from 0 upward, if you want the whole stockpile available all the time.
- Add several groups if you want the parameter's available material to change from group to group, which is the basis of [layers](concepts/union) and of [combination](concepts/combination).
- Check that the list itself is not [empty](empty-list). A table cannot be built over nothing.
