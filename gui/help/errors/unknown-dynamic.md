# A dynamic that is not in the list

An instrument, a [table](concepts/list-table-ensemble-order) cell, or a [ratio](concepts/selection-principles) weight names a dynamic that does not appear in the piece's master dynamics list.

## Why this matters

Dynamics are declared once, at the top level of the [structure formula](concepts/structure-formula), as an ordered master list. Everything downstream refers to that list rather than repeating it: the dynamics table holds indices into it, an instrument's own dynamics field names the subset that player can actually produce, and the score printout resolves indices back to names through it.

That single list is also what gives dynamics their order. Because the list is ordered, `ppp` through `fff`, index arithmetic over it is musically meaningful, which is what makes a [tendency mask](concepts/selection-principles) over dynamics work: the mask moves through the list as a range of proportions, so drifting from the low end to the high end is a crescendo across the [variant](concepts/variant). A name invented outside the list has no position and so cannot take part in any of that.

## How to fix it

- Add the dynamic to the master list, placing it at the position its loudness deserves so that ordering-sensitive principles behave.
- Check the spelling. `mp` and `mf` are easily confused, and matching is exact.
- Remove the dynamic from this instrument if the player is genuinely restricted. Instruments may use a subset of the master list, but not [an empty one](no-dynamics).
