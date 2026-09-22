# Instrument order

> How instruments are drawn from the active ensemble, event by event - which may hold more than one group at once. All six [selection principles](concepts/selection-principles) are available here.

Once the [instrument ensemble](fields/instrument-ensemble) has decided which group is active, the order principle reads that group in time and produces the actual succession of instruments. This is where the instrumentation acquires its rhythm.

The choice has more consequences than it might appear, because the instrument determines [chord size](fields/instrument-chordsize) and therefore, under instrument-derived [density](fields/density), the vertical thickness of every entry point. Under a [hierarchy](fields/hierarchy) beginning with `Ins`, it also determines which dynamics, performance modes and durations are available for that event. The instrument order principle is often the single most audible decision in a formula.

## Which principle

**Series** distributes the group's instruments evenly — over one cycle each instrument appears exactly once. The result is a rotating, well-mixed instrumentation where no player dominates.

**Alea** produces clumps: one instrument may appear four times running and another not at all for a stretch. Less even, more unpredictable.

**Group** creates blocks — one instrument for several consecutive events, then another. This is the principle that produces recognisable solo passages within a mixed ensemble, and it is worth trying whenever a texture sounds shapelessly variegated.

**Ratio** makes one instrument primary and another a rarity: weights `5 1 1` in a three-instrument group give a clear foreground and two occasional colours.

**Sequence** fixes a rotation exactly — a fixed alternation between two players, for example.

**Tendency** moves through the group positionally, so a variant can migrate from the instruments written at the start of the group to those at the end. Write the group in a deliberate order (lowest to highest, softest to loudest) and this becomes a gradual instrumental transformation across the variant.

## Example

Active group: `guitar1, guitar2, piano, basedrum` (chord sizes 6–6, 1–6, 1–10, 1–1), instrument density.

With **series**, twelve events cycle through all four, so the density profile is regularly mixed: a six-note guitar chord, then perhaps a single drum stroke, then a piano chord.

With **group** (repetitions 2–4) the same material gives:

```
guitar1 guitar1 guitar1 | basedrum basedrum | piano piano piano piano | guitar2 guitar2 guitar2
```

Three dense guitar chords, then two bare strokes, then a piano passage. The texture now has paragraphs. Nothing about the material changed — only the order principle.

With **ratio** `1 1 1 8`, the bass drum dominates and the pitched instruments become punctuation in a percussion piece.

## Related

- [instrument ensemble](fields/instrument-ensemble)
- [instrument table](fields/instrument-table)
- [density](fields/density)
