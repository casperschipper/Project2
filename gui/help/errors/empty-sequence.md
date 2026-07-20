# The sequence has no values

A *sequence* was chosen here, but no positions were given for it to follow.

## Why this matters

Sequence is the one [selection principle](concepts/selection-principles) that is not a rule for generating order but a statement of order. Where *alea* draws at random and *series* exhausts the supply before repeating, sequence simply plays the positions you write, in the order you write them, cycling back to the start when it reaches the end. It is how you retain direct control over a parameter while leaving the rest of the formula to the program.

An empty sequence has no order to state. There is nothing to cycle through, so the parameter can never yield a value, and whatever it governs, either the choice of elements from the [ensemble](concepts/list-table-ensemble-order) or the choice of which table groups form that ensemble, cannot proceed.

Note the level at which a sequence applies. As a parameter's *order* principle, its values are [list indices](index-out-of-range). As an ensemble's group selection, its values are table group positions.

## How to fix it

- Write the positions you want, in order. They may repeat: `0 1 0 2` is a perfectly good four-step cycle.
- Confirm you are counting from zero, and that every position exists in the list or table this sequence refers to.
- Switch to *alea* or *series* if you do not in fact want a fixed order. Those need no values at all.
