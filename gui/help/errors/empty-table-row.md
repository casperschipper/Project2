# A table group is empty

One of the groups in this [table](concepts/list-table-ensemble-order) contains no elements.

## Why this matters

A group is a set of list indices that belong together and are put into the [ensemble](concepts/list-table-ensemble-order) jointly. It is the unit of selection: when a parameter forms its ensemble, it takes whole groups, and the [selection principle](concepts/selection-principles) then works over the elements those groups contributed.

An empty group is a unit that carries nothing. If it is ever chosen, it contributes no elements to the ensemble, and the selection principle is left with an empty supply to draw from. Under [union](concepts/union) that merely thins the pool, which is confusing; without union, where each group becomes its own [layer](concepts/union), it produces a layer that cannot sound at all.

Empty groups also distort counting. [Combination](concepts/combination) pairs groups positionally with the instrument table's, and an empty group still occupies a position, so it will happily align with a full instrument group and then supply it with nothing.

## How to fix it

- Put at least one list index in the group. A group of one element is perfectly legitimate and means that element is fixed whenever this group is active.
- Delete the group if it was left over from editing. Deleting it changes the positions of the groups after it, so check any [ensemble sequence](concepts/selection-principles) or [combination](concepts/combination) partner afterwards.
- If you meant this group as a rest or a silence, note that Project Two does not express silence this way; look at the [duration relation](concepts/duration-relation) instead.
