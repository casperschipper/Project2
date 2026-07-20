# Group

> Deliberate immediate repetition: choose an element, repeat it a number of times, choose the next. Both the element and the repetition count have their own selection behaviour.

The `group` principle is the program's way of producing *blocks* rather than a spray of single events. It holds a current value and a counter. While the counter is above zero it keeps returning the same value; when it runs out, a new element is drawn and a new repetition count is drawn, and the process continues.

You configure four things:

- **element** — how the next value is chosen: `alea` or `series`.
- **repetition** — how the next repetition count is chosen: `alea` or `series`.
- **repetitions min / max** — the range of counts, e.g. 2 to 5.

Musically this is what gives a texture *grain*. With every parameter on `series` or `alea`, each event is a fresh decision and the surface is uniformly restless; nothing is held. `Group` introduces persistence — a dynamic that stays put for a few notes, a register that is occupied and then abandoned, an entry delay that establishes a pulse before changing it. It is also the natural principle for [density](concepts/density), where you often want a passage to be consistently thin or consistently thick rather than flickering between one and four voices event by event.

Note that `group` produces repetition *of values*, not of patterns. It is not a loop; see [sequence](concepts/sequence) for that.

## Example

Ensemble: `p mf f ff`. Element `series`, repetition `series`, repetitions 1–4.

Because both slots use `series`, the four dynamics are exhausted before any returns, and the four possible counts (1, 2, 3, 4) are likewise exhausted before any returns. One possible reading:

```
mf mf mf   ff   p p p p   f f
 (3)       (1)   (4)      (2)
```

Ten events, four blocks, each dynamic used once and each count used once. This is a strongly ordered texture that still sounds unpredictable, because the *pairing* of value with count is free.

Change element to `alea` and the values may repeat between blocks — `mf mf mf | mf | p p` becomes possible, which produces a long stretch of one dynamic broken by a barely perceptible seam. Change repetition to `alea` and the block lengths lose their evenness.

## Repetitions and hierarchy

Within a block the value is already fixed, so if a constraint from the [hierarchy](concepts/hierarchy) rules it out mid-block, no alternative can be substituted — the event is emitted as a wrong element with a [comment](fields/comment). Only at a block boundary can the constraint influence which element is picked next. If you are getting many comments on a `group` parameter, either shorten the maximum repetition count or make the parameter's ensembles more broadly compatible with whatever precedes it in the hierarchy.

## Related

- [series](concepts/series) — the no-repetition counterpart
- [density](concepts/density) — a common home for `group`
- [selection principles](concepts/selection-principles)
