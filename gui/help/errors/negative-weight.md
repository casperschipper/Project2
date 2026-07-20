# A ratio weight is negative

One of the weights in this [ratio](concepts/selection-principles) principle is below zero.

## Why this matters

Ratio selects at random from a supply, but each element carries a factor saying how many times it may be drawn before it leaves the supply; once the supply is exhausted, both it and the factors are regenerated. The factor is therefore a count of permitted occurrences, which is why it must be a whole number of zero or more.

Zero is meaningful and useful: it blocks an element, so it stays in the [list](concepts/list-table-ensemble-order) and keeps every index after it in place, but never sounds. Larger numbers make an element proportionally more frequent. There is no operation for which a negative count would say anything: an element cannot occur minus two times, and no interpretation as "avoid this" exists that zero does not already cover.

Note that weights are declared per list index, and any index you do not mention defaults to zero. So blocking happens by omission as easily as by intent, which is worth remembering when a group turns out to be [entirely blocked](ratio-all-blocked).

## How to fix it

- Set the weight to `0` if you meant to block the element.
- Set it to a positive whole number to say how often the element may be drawn per cycle.
- To make an element rare rather than absent, give it `1` while giving the others larger values. Ratio expresses proportion, so `1` against `4` is a quarter as frequent, not merely less frequent.
