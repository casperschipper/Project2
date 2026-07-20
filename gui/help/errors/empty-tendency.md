# The tendency mask has no sections

A *tendency* [selection principle](concepts/selection-principles) was chosen, but no sections were defined for it.

## Why this matters

A tendency mask is how Project Two expresses directed change over time. Rather than selecting uniformly from the whole [ensemble](concepts/list-table-ensemble-order), it restricts the selection at each moment to a moving window over the ensemble, and the window itself travels as the [variant](concepts/variant) proceeds. That is what lets a parameter drift: dynamics rising from the soft end of the list to the loud, entry delays contracting from long to short.

The mask is built from sections. Each section takes a portion of the variant's length and states where the window sits at the start of that portion and where it has arrived by the end, each as a pair of bounds. Placing sections one after another lets you build a shape with several stages, a rise then a plateau then a collapse.

With no sections there is no window and no shape, so the mask describes nothing at all. It is not equivalent to selecting freely; it is an unfinished statement.

## How to fix it

- Add at least one section, with a portion and a start and end range. A single section that runs from a narrow low window to a narrow high one is the simplest useful mask, and it is a straight traversal of the list.
- Add further sections to build a multi-stage shape; their portions describe their relative shares of the variant.
- Switch to *alea* or *series* if you do not want directed change. Those select over the whole ensemble and need no configuration.
