# The seed must be a whole number, zero or above

The random seed is not a non-negative whole number.

## Why this matters

Most of the selection in Project Two is aleatoric. Which groups form the [ensemble](concepts/list-table-ensemble-order), which elements the [selection principles](concepts/selection-principles) draw and in what order, are decided by chance within the constraints you have written. That is the point of the program: the [structure formula](concepts/structure-formula) describes a field of possibilities, and a [variant](concepts/variant) is one realisation of it. As the manual puts it, other variants reveal the form potential of the formula step by step.

The seed is what makes that chance reproducible. Given the same formula and the same seed, the same variant comes out every time, so you can return to a result you liked, share it, or change one detail of the formula and hear precisely what that change did rather than a different roll of the dice. Change only the seed and you get a genuinely different variant of the same formula.

It is a whole number because it names a starting state of the generator, not a quantity. Fractions and negative values do not name any state.

## How to fix it

- Enter any whole number of zero or above. `0`, `1`, `42` are all equally valid; no value is more random than another.
- Change only the seed to explore alternative realisations of a formula you are otherwise happy with.
- Keep the seed fixed while you edit the formula, so that each change you hear is attributable to the edit rather than to chance.
