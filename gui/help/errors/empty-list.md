# This parameter's list is empty

The [list](concepts/list-table-ensemble-order) for this parameter contains no items.

## Why this matters

The list is the stockpile: everything this parameter can possibly contribute to the piece has to be in it. The [table](concepts/list-table-ensemble-order) groups indices into the list, the [ensemble](concepts/list-table-ensemble-order) is assembled from those groups, and the [selection principle](concepts/selection-principles) draws from the ensemble. Every stage above the list is a way of arranging and selecting what the list already holds. With nothing in it, the entire chain has nothing to arrange, and any index in the table is by definition [out of range](index-out-of-range).

Project Two is designed around long lists that outlive individual variants. The manual's reasoning is that the composer should not have to keep feeding new data: you write one full stockpile once, and then form different groups and different variants over it. That only works if the stockpile is there.

## How to fix it

- Add the values you want available for this parameter. Entry delays and durations accept decimals and fractions alike, so `0.25` and `1/4` are both fine.
- Add generously. Items that are in the list but named in no [table](concepts/list-table-ensemble-order) group simply do not occur, so an over-full list costs nothing and leaves room for later variants.
- For performance modes, note that the master list is built from what your instruments declare, so define the instruments' modes and the list will follow.
