# Rest mode

> Whether autonomous rests (EMR-3 §7.4) are inserted into the timeline at all, and if so, what kind of entry a rest is placed in front of.

REST is unlike every other parameter here: it is never part of the [hierarchy](fields/hierarchy) and can never be main parameter, because it does not resolve a *property* of an entry point — it works on entry points themselves, after everything else (instrument, entry delay, duration, dynamics, performance, register, harmony) has already been decided for the whole layer. It then walks that already-complete timeline once, deciding where to insert silence, and pushes everything from each insertion point onward later by the inserted rest's own length. Rests are calculated and inserted independently per [layer](concepts/layers).

## Off

The default. No rests are inserted; the timeline is exactly what the other six parameters produced. The [rest list, table, ensemble and order](fields/rest-list) are not required and have no effect.

## The search

Once switched on, REST repeatedly does the same thing: draw an offset — a percentage, between the two numbers you give as the *entry range*, of the [variant duration](fields/variant-duration) — add it to wherever the last rest (or the start of the layer) left off, and walk forward to the next entry that qualifies. A rest is placed immediately before that entry, with a length drawn from the [rest list](fields/rest-list), and everything from there onward is pushed later by that length before the next offset is measured. The entry range is deliberately wide (e.g. `5` to `20`, not a single fixed number) so successive rests fall at a somewhat unpredictable distance from one another rather than at perfectly regular intervals.

Which entries qualify is the one choice this field makes:

**Before a sound entry.** Any tone onset qualifies, regardless of what is still sustaining from an earlier, longer tone. The rest lands on the very next attack the search reaches.

**Before a general entry.** Only an onset with nothing currently sustaining over it qualifies — an onset still covered by an earlier tone's duration is skipped, and the search continues to the next one that is genuinely clear. This is evaluated freshly against the timeline as it stands at that point in the search (including any earlier rests already placed), not decided in advance for the whole layer, since an earlier rest can itself free a later entry that was concealed before the shift.

The difference only matters when tones overlap their neighbours — under a duration relation and hierarchy that never produce overlap, the two settings behave identically.

## Entry range

Two percentages, `d1` and `d2` (0 to 100), of the variant duration. Each rest's offset is drawn uniformly between them. A narrow, low range (`5` to `10`) places rests close together and often; a wide, high range (`40` to `80`) places them rarely, and the width between the two numbers controls how irregular the spacing feels.

## Interaction with common harmony

Under [union](fields/union) "common harmony", REST runs on each layer's own timeline *before* the layers are merged and harmony resolves across them — "REST at last place but one, HARMONY last" (EMR-3 §7.4). This happens automatically; there is nothing to configure differently for this case.

## Related

- [rest list, table, ensemble, order](fields/rest-list)
- [hierarchy](fields/hierarchy)
- [union and combination](concepts/union-and-combination)
- [duration relation](fields/duration-relation)
