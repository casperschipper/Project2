# Harmony requires Har last in the hierarchy

[Union](fields/union) is set to common-harmony, but Harmony is not the last parameter in the [hierarchy](fields/hierarchy).

## Why this matters

Under common-harmony (EMR-3 §6.2's "s=1"), the instrument groups stay separate as their own layers, and every parameter except HARMONY resolves independently per layer - but HARMONY itself is forced to resolve last, and only once: after every layer's own rhythm is fixed, the layers are fitted together into one true chronological timeline, and a single continuous pitch stream walks across all of them together. That ordering is the whole point of common-harmony - there is no "final merged timeline" for HARMONY to walk until everything else, in every layer, is already settled.

## How to fix it

- Move Harmony to the end of the hierarchy. The remaining order is still entirely yours.
- If you want Harmony to resolve inside each layer's own pass instead (in whichever position you like), switch [union](fields/union) to "none" - each layer then gets its own independent harmony resolution.

## Related

- [union](fields/union)
- [hierarchy](fields/hierarchy)
- [harmony principle](fields/harmony-principle)
