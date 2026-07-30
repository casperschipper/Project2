# Number of variants

> How many variants to calculate in this run (EMR-3 9.8: N-VARIANTS). All of them share one continuing selection-cycle state.

A single run of the engine is what EMR-3 calls a "variant group": one [seed](fields/seed), one structure formula, and - as of this field - as many variants as you ask for. Layers within one variant have never restarted a [selection principle](concepts/selection-principles)'s cycle partway through; this field extends that same guarantee across variants too. A parameter's cycle - which group is drawn next, where a SERIES walk through a list currently stands, HARMONY's transposition cycle - simply keeps going from the last layer of one variant into the first layer of the next. It is reset only by starting a genuinely new run with a new seed, never by asking for more variants.

TENDENCY is the one exception: its mask position is defined relative to one variant's own timeline (EMR-3 4.6), so it restarts fresh at the beginning of every variant, whether or not anything else does.

## Example

`Number of variants: 4` with two instrument groups (`union none`) produces 4 variants of 2 layers each - 8 layers' worth of continuous draws in total, not 4 independent pairs.

## Notes

- With more than one variant, the Output screen shows a variant selector, and each variant gets its own score/entries/MIDI files (`score_variant0...`, `score_variant1...`, and so on) instead of the single `score...` set a lone variant produces.
- This is a different way of exploring a formula than stepping through [seeds](fields/seed) one at a time: cycling seeds gives you unrelated realisations to compare, while several variants in one run are explicitly a continuous unfolding of the same cycles - useful when the *continuation* itself is what you want to hear, not just another independent roll.

## Related

- [seed](fields/seed)
- [union](fields/union)
