# Same interval listed twice in the adjacency matrix

A hand-written `(adjacency ...)` matrix gives two separate entries for the same "given" interval.

## Why this matters

Each entry in the adjacency form of the [interval matrix](fields/harmony-matrix) (`(given (succ succ ...))`) is the *complete* list of what may follow that given interval - there is exactly one row per interval in the underlying matrix, so listing the same given interval twice would mean two different, contradictory rows.

This form is only reachable by editing a `.sexp` file directly - the GUI's own matrix editor always produces a plain grid, where this ambiguity cannot arise.

## How to fix it

- Merge the two entries into one, listing every allowed successor for that interval together: `(3 (1 2 4))` rather than `(3 (1 2))` and `(3 (4))` separately.
