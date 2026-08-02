# Chord principle and density disagree

HARMONY's [principle](fields/harmony-principle) and [density](fields/density) don't agree about who decides how many notes sound together.

## Why this matters

Per EMR-3 §9.2: if HARMONY uses the CHORD principle, it becomes the main parameter and vertical density can be neither autonomous nor instrument-driven - the density *is* the size of whichever chord got drawn. The reverse holds too: density can only be chord-density when CHORD is actually the active harmony principle, since nothing else produces a whole chord to measure the size of.

Ordinarily the interface keeps these in sync automatically - switching [principle](fields/harmony-principle) to or from Chord on the Harmony screen updates [density](fields/density) to match. This diagnostic mainly catches a hand-edited file, or a project carried over from before the sync existed.

## How to fix it

- To use CHORD: set density to chord-density (or just re-select Chord as the harmony principle from the Harmony screen, which does this for you).
- To use an autonomous or instrument-driven density instead: switch the harmony principle away from Chord, to Row or Interval.

## Related

- [harmony principle](fields/harmony-principle)
- [density](fields/density)
