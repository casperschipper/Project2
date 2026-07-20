# An instrument has no name

One of the instruments in the list was defined without a name, or with an empty name.

## Why this matters

Instrument names are how Project Two identifies the players in your piece, and they are load-bearing in more places than they first appear. The name is what the score printout puts against each tone, and it is what lets you write readable references elsewhere: [tables](concepts/list-table-ensemble-order) and [ratio weights](concepts/selection-principles) may name an instrument directly instead of using its position number, so the formula stays legible when you reorder the list.

An unnamed instrument would break that. It could still be selected and could still play tones, but nothing in the printed result would say who is playing them, and no reference by name could ever reach it. Names must also be distinct from one another for the same reason: a reference by name has to resolve to exactly one player.

## How to fix it

- Give the instrument a name. Anything readable works: `vln`, `Violin 1`, `perc-lo`.
- If this instrument was left over from an earlier sketch and is not meant to be part of the piece, delete it rather than leaving it blank. An empty entry still occupies a list index, and every index in the [instrument table](concepts/list-table-ensemble-order) counts positions from the top.
- If you intend several similar players, give them distinguishing names now rather than later. Renaming after the tables are written means checking that nothing referred to the old name.
