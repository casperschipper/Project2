# Instrument dynamics

> The intensities this instrument can produce. A dynamic can only be assigned to a tone if the instrument playing it has that dynamic.

Instruments do not share a dynamic range. A marimba has no convincing `ppp`; a soft-strung guitar has no `fff`. Listing each instrument's available intensities records that, and the program enforces it in the same way it enforces [performance modes](fields/instrument-performance) and [durations](fields/instrument-durations).

Every name used must be a member of the master dynamics list; the interface reports unknown names as errors.

## Example

```
guitar1     p mf f ppp
guitar2     p mf f ff
piano       ppp pp p mf f ff fff
basedrum    ppp pp p mf f ff fff
marimba     mf f ff fff
```

The pattern here is the piece's dynamic architecture, whether or not you thought of it that way. The piano and bass drum span everything. The guitars are confined to the soft and middle range; the marimba to the middle and loud. `ppp` is available to guitar1, piano and bass drum but not guitar2 or marimba; `fff` only to piano, bass drum and marimba.

Under a hierarchy of `Ins → Dyn`, a variant that happens to favour the marimba simply cannot be quiet. Under `Dyn → Ins`, a passage of `fff` will be scored for piano, drum and marimba because they are the only candidates. In neither case did you write a rule about it — the dynamic shape and the instrumentation are entangled through this table, and which one leads is the hierarchy's decision.

## Practical advice

Check the intersection. If your active instrument group is `guitar1, guitar2` and your active dynamics group is `ppp pp fff`, then only `ppp` is playable and only by one of the two instruments. Nearly every event will be a wrong element carrying a [comment](fields/comment). The fix is either broader groups or [combination](concepts/union-and-combination), which pairs the instrument group with a dynamics group designed to suit it.

As with performance modes, it is worth keeping some middle ground — `mf` or `f` — available to every instrument, so that no layer can be left with nothing playable.

## Related

- [dynamics list](fields/dynamics-list)
- [dynamics table](fields/dynamics-table)
- [union and combination](concepts/union-and-combination)
