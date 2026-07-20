# Hierarchy

> The order in which the five parameters are resolved for each event. The first is free; the rest are conditioned by what has already been fixed.

You are ordering five elements: **Ins** (instrument), **Per** (performance mode), **Dyn** (dynamics), **Ent** (entry delay) and **Dur** (duration). Every one must appear exactly once. The full reasoning is in [hierarchy](concepts/hierarchy); this page covers the practical decision.

The first parameter is the *main parameter*. Its [selection principle](concepts/selection-principles) runs without restriction, so its structure appears in the score exactly as designed. Each later parameter draws under the accumulated constraints of everything before it, and when no admissible value exists it emits a wrong element marked with a [comment](fields/comment).

Ask yourself: which single dimension of this piece do I want to be exactly what I wrote? Put that first. Everything else is negotiable, and the hierarchy is your ranking of how negotiable.

## Example

`Ins → Per → Dyn → Ent → Dur`

Instrumentation is exact. Performance modes are drawn from what the chosen instrument can play. Dynamics are drawn from what that instrument permits. Entry delay is free of instrumental constraint. Duration comes last, so if the [duration relation](fields/duration-relation) is `shorter-than-entry` it is bounded by the entry delay just fixed.

`Dyn → Ins → Per → Ent → Dur`

Now the dynamic profile is exact — every dynamic in your ensemble occurs in the proportions your principle produces. Instrument is then restricted to instruments that can play the dynamic already chosen, so a passage of `fff` will simply not be given to an instrument whose range stops at `f`. The instrumentation has become a consequence of the dynamic shape. This is a substantially different piece from the same lists and tables.

## Constraints the program enforces

- **Per-note modes require `Ins` first.** If [dynamics mode](fields/dynamics-mode), [performance mode](fields/performance-mode), or the [duration relation](fields/duration-relation) uses per-note, the instrument must precede it — the chord size, and therefore the number of values needed, is a property of the instrument.
- **Instrument-derived [density](fields/density) requires `Ins` first**, for the same reason.
- **`Ent` before `Dur`** is what you want when the duration relation is `equals-entry` or `shorter-than-entry` and the rhythm should drive the durations. Put `Dur` first instead and the relation is applied in reverse: entry delays shorter than the chosen duration are rejected. Both are valid; they express opposite priorities.

## Reading the result

If a variant is producing many comments, the hierarchy is asking too much of its lower parameters. Look first at whether the lower parameter's table groups are broad enough, then at whether they were designed to match the upper parameter's groups — [combination](concepts/union-and-combination) exists to guarantee exactly that pairing.

## Related

- [hierarchy](concepts/hierarchy)
- [comment](fields/comment)
