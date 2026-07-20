# Two tables that must align have different numbers of groups

This parameter is set to *combination*, which pairs its table groups one to one with the instrument table's, but the two tables do not have the same number of groups.

## Why this matters

[Combination](concepts/combination) is the mechanism by which a parameter gives up its own independence and follows the instrument parameter instead. Normally each parameter picks its own group from its own [table](concepts/list-table-ensemble-order) according to its own [selection principle](concepts/selection-principles). Under combination it does not choose: it adopts the sequence of group indices that the instrument parameter chose, and assembles its [ensemble](concepts/list-table-ensemble-order) from the groups sitting at those same positions.

That only makes sense if position *n* exists in both tables. If the instrument table has four groups and this one has two, then whenever the instrument parameter selects group 3, combination has nothing to pair it with. The correspondence is positional, not by content, which is exactly what makes it expressive: you write instrument group 2 and dynamics group 2 to describe the same musical situation, so choosing one automatically brings the other. Groups that have no counterpart break that intention.

## How to fix it

- Add or remove groups so both tables have the same number of rows. The usual fix is to give this table one group per instrument group, each describing the material that belongs with those players.
- If the parameters are not really meant to move together, switch this parameter's ensemble away from combination to `alea`, `series` or an explicit `sequence`, and it will select its own groups freely.
- If only some groups are meant to correspond, note that combination is all or nothing. Model the exception by repeating a group, so that the counts match and the repeated group is simply reused.
