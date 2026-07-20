# More instrument groups requested than the table defines

The formula asks for more instrument groups to be drawn than the [instrument table](concepts/list-table-ensemble-order) contains.

## Why this matters

The number of instrument groups says how many groups are taken from the table to build the instrument [ensemble](concepts/list-table-ensemble-order). It is a consequential number, because without [union](concepts/union) each group in the ensemble becomes its own [layer](concepts/union): a separate musical strand with its own stream of values, all sharing the same [variant duration](concepts/variant) but otherwise independent. Asking for three groups is asking for three layers.

It also propagates. Any parameter set to [combination](concepts/combination) adopts the instrument ensemble's group indices, so the number of groups drawn for instruments determines how many are drawn for those parameters too.

If you ask for more groups than exist, the drawing does not fail; the [selection principle](concepts/selection-principles) regenerates its supply once exhausted, so groups will simply be reused. That is legitimate, but it means a request for six groups over a table of three gives each group twice rather than six distinct ones, which is usually not what was intended. Hence a warning rather than an error.

## How to fix it

- Add groups to the instrument table until it holds at least as many as you are asking for.
- Lower the requested number to match the table, if the table is what you intended.
- Leave it, if deliberate repetition of groups is the effect you want. Note that with *alea* the repetition is unpredictable, whereas with *series* every group is used once before any recurs.
