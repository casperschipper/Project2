# A tendency bound is outside 0 to 1

One of the bounds in a [tendency](concepts/selection-principles) section lies below 0 or above 1.

## Why this matters

Tendency bounds are not list indices, and this is the most common misunderstanding about them. They are **proportions of the list**, expressed between 0 and 1: `0` means the very beginning of the [ensemble](concepts/list-table-ensemble-order), `1` means the very end, `0.5` the middle. So a section running from `0 0.2` to `0.7 1` describes a window that starts at the bottom fifth of the material and has widened and travelled to the top third by the end of that section.

The proportional form is what makes a mask portable. The same mask describes the same musical gesture, a crescendo, a rhythmic contraction, whether the underlying list has five items or fifty, and it survives adding items to a list without needing rewriting. Had bounds been indices, every mask would have been coupled to the exact length of the list it was written against, and the [list, table, ensemble chain](concepts/list-table-ensemble-order) would lose the independence it is built for.

A value outside the unit range has no position to correspond to. The engine itself does not tolerate it and will fail outright, so it is caught here.

## How to fix it

- Rewrite the value as a proportion between 0 and 1. If you meant the fourth item of an eight-item list, that is roughly `0.4`, not `4`.
- Use `0` and `1` for the extremes; they are valid.
- To make a mask that sweeps the whole list, write a section from `0 0.2` to `0.8 1`, not from `0` to the list's length.
