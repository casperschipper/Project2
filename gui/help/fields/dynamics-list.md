# Dynamics list

> The master list of intensities available to the piece. Every instrument's own dynamics must be drawn from this list.

This is the [list](concepts/list-table-ensemble-order) for the dynamics parameter: the complete vocabulary of intensities, in whatever notation you choose. The conventional `ppp` to `fff` is the usual choice, but the names are yours — the program treats them as identifiers and attaches no numeric meaning to them beyond their position.

Position does matter for one principle. [Tendency](concepts/tendency) reads a group positionally, so if the list runs from softest to loudest, a tendency window travelling upward is a crescendo across the variant. Write the list out of order and tendency still works, but it no longer traces a dynamic curve. Keep it ordered unless you have a reason not to.

## Example

```
index   0    1    2    3    4    5    6
value  ppp   pp   p    mf   f    ff  fff
```

Seven degrees, evenly spread. This is enough to give [series](concepts/series) something to do — each cycle visits all seven — while remaining small enough that a [table](fields/dynamics-table) group of three or four values reads as a distinct register.

A shorter list is often more effective than a longer one. With fifteen gradations, adjacent values are not distinguishable in performance, and a `series` cycle takes so long that the evenness it guarantees is inaudible. Seven is already generous.

## Relation to the instruments

Each instrument names a subset of this list as its own available [dynamics](fields/instrument-dynamics), and every name used there must appear here; unknown names are reported as errors. The consequence is that this list is an upper bound, not a promise: a value present here but absent from every instrument's set can never be realised, and every attempt to use it produces a [comment](fields/comment).

If you add a dynamic to this list, add it to at least one instrument, or it is decoration.

## Related

- [dynamics table](fields/dynamics-table)
- [dynamics mode](fields/dynamics-mode)
- [instrument dynamics](fields/instrument-dynamics)
