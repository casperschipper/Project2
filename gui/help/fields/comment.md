# Comment

> A free text field for your own notes about this structure formula. It is stored with the project and is not part of what the engine reads.

A structure formula is a set of decisions, and the decisions are not self-explaining three weeks later. This field is where you record the reasoning: why the entry-delay table is partitioned the way it is, what "group 2" was supposed to sound like, which [seed](fields/seed) produced the variant you liked, what you tried and rejected.

It is worth being disciplined about this. Because a formula produces many different variants, you can easily lose track of which formula produced which result, and of what you had actually determined versus what a particular seed happened to supply. A few lines here — "seed 7, 30 s: the good one; layer B too dense above density 3" — will save more time than any other habit.

Nothing here affects the generated score. The field is not emitted to the structure formula; it lives only in the project file.

## Example

```
Two layers, no union. Combination on for dynamics and duration so each
instrument group keeps its own vocabulary.

Instrument groups:
  0  everything (unused so far)
  1  guitar1 alone - the sparse layer
  2  piano + basedrum - the fast layer

Entry delay group 1 deliberately long (0.4-0.6) so the guitar layer
reads as punctuation against group 2's 0.1-0.3.

Seeds tried: 3 (good), 5 (too static), 11 (best so far, keep).
Density high=4 makes the piano layer saturate; 2 is the limit.
```

## A different sense of the word

The manual uses "comment" for something else, and it is worth knowing about so the two do not get confused. In the generated score, a *comment* is an automatic annotation marking a **wrong element**: a point where a parameter value violated the rules of your formula because no admissible value could be found in the ensemble. The offending parameter is marked with a letter.

Those score comments are diagnostic information about your formula, not notes you write. A steady stream of them usually means the [hierarchy](concepts/hierarchy) is over-constraining a lower parameter, or that groups which are selected together were not designed to be compatible — see [union and combination](concepts/union-and-combination).

## Related

- [seed](fields/seed)
- [hierarchy](concepts/hierarchy)
