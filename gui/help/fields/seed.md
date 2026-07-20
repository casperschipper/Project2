# Seed

> The starting point for the program's random number generator. The same seed with the same structure formula always produces exactly the same score.

Almost every decision in PROJECT TWO involves chance — which group enters the ensemble, which element the [selection principle](concepts/selection-principles) draws next, where a shuffle lands. The seed makes that chance reproducible. It is a whole number, zero or above.

This matters more than it first appears. A [variant](fields/variant-duration) is one reading of your structure formula, not the only one; the formula's real content is the *set* of variants it can produce. The seed is how you navigate that set. Keep the formula fixed and change the seed, and you hear different readings of the same compositional decisions — this is the single most useful thing you can do while learning a formula, because it separates what you actually determined from what chance happened to supply this time.

It also makes comparison honest. If you want to know what changing one duration group does, change the group and keep the seed. Whatever differs is attributable to your edit. Change both and you have learned nothing.

## Example

Seed 3, variant duration 30 s, everything else as written: you get a particular score. Save it, close the program, reopen it, generate again with seed 3 — you get the identical score, note for note.

Now step through seeds 1 to 10 without touching anything else. Ten variants. Some will feel characteristic of your formula; one or two will surprise you. If nearly all of them sound the same, your formula is over-determined and chance has little room — consider looser [selection principles](concepts/selection-principles) or broader table groups. If they have nothing in common, it is under-determined, and you are hearing the material rather than a piece.

## Notes

- The seed affects only the random draws. It has no musical meaning of its own — seed 3 is not "better" than seed 4, and there is no ordering among them.
- Note down the seed of any variant you want to keep. Together with the formula it is a complete description of the result.
- Structural changes rearrange the sequence of random draws, so the same seed before and after an edit will not produce "the same score with one thing changed" — it will produce a different variant. The reproducibility guarantee is exact only for an unchanged formula.
