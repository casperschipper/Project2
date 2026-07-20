# Fewer than one instrument group requested

The formula asks for zero or fewer instrument groups.

## Why this matters

The instrument [ensemble](concepts/list-table-ensemble-order) is built by taking a number of groups from the [instrument table](concepts/list-table-ensemble-order). That number is also the number of [layers](concepts/union) the variant will have, unless [union](concepts/union) merges them into one, and it is the number that any parameter using [combination](concepts/combination) will follow.

Asking for zero groups produces an empty ensemble. There would be no instruments available to the selection process, no layer to place tones in, and consequently no score. The chain from list through table to ensemble would terminate before it reached the point of choosing anything.

One is the meaningful floor, and one is a perfectly ordinary value: a single group means a single layer drawing on one fixed set of players, which is the simplest and often the clearest arrangement.

## How to fix it

- Set the number to `1` for a single layer.
- Set it higher for several simultaneous layers, keeping it at or below the number of groups in the table so that each layer gets a distinct group; asking for [more than the table holds](more-groups-than-rows) causes groups to be reused.
- Remember that layers are not the same as instruments. One group may contain many players; the group count is about strands of the texture, not about how many people are playing.
