# Two things share a name

Two instruments, or two dynamics, have been given the same name.

## Why this matters

Names in Project Two are identifiers, not labels. The [structure formula](concepts/structure-formula) lets you refer to an element by its name instead of by its position, in [table](concepts/list-table-ensemble-order) cells and in [ratio](concepts/selection-principles) weight pairs, precisely so that a formula stays readable and survives reordering of the list. That convenience depends on a name resolving to exactly one element.

With a duplicate, resolution becomes arbitrary: a reference to that name finds the first match and silently ignores the second, so one of the two elements becomes unreachable by name while still occupying a list position and still being selectable by index. The result is a formula that behaves differently from how it reads.

For dynamics there is a further reason. The dynamics list is *ordered*, and its order is its meaning, from softest to loudest. A duplicate name in an ordered list makes the position of that dynamic ambiguous, which undermines the principles that traverse the list by position, above all a [tendency mask](concepts/selection-principles) used to shape a crescendo across the [variant](concepts/variant).

## How to fix it

- Rename one of them to something distinct: `vln-1` and `vln-2` rather than two `vln`.
- Delete the duplicate if it was created by accident, then check any [table](concepts/list-table-ensemble-order) indices, since removing a list item shifts every position after it.
- If you genuinely want two players with identical properties, keep both but give them different names. They will then behave independently and can be addressed separately.
