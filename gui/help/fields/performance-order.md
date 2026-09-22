# Performance order

> How performance modes are drawn from the active ensemble, event by event - more than one group under combination. All six [selection principles](concepts/selection-principles) are available.

The order principle decides the succession of articulations. Because modes of performance are usually strongly characteristic — a `pizzicato` is not a shade of `normal`, it is a different sound — this parameter tends to produce the timbral foreground of a variant.

That argues for principles with some persistence. A mode that changes at every single event is heard as instability rather than as articulation; the same modes held in blocks are heard as sections of a piece.

## Which principle

**Group** is often the best choice here. Holding one mode across several consecutive events gives the layer recognisable timbral paragraphs — a passage of `muted` playing, then a passage of `overtone1`. This is what makes special articulations legible as material rather than as decoration.

**Ratio** establishes a norm and exceptions: weight `normal` at 6 against the others at 1 each, and the special modes become genuine events. Because ratio is exhaustive over its weighted supply, each rarity is guaranteed to occur once per cycle rather than being left to chance.

**Series** rotates through the group's modes evenly. Every articulation is equally present; the surface changes constantly.

**Alea** gives the same vocabulary unshaped, with accidental runs and gaps.

**Tendency** migrates through the group positionally, so with the modes written in a deliberate order — say from the most ordinary to the most extreme — the layer can transform its manner of playing across the variant.

**Sequence** fixes a rotation of modes exactly.

## Example

Active group `normal, normal, muted, overtone1, pizzicato, bowing` (with `normal` doubled).

**Series**, one cycle of six:

```
muted  normal  bowing  normal  pizzicato  overtone1
```

Every mode once, `normal` twice, in random order — a constantly recolouring surface. Under a hierarchy beginning with `Ins`, each of these must be playable by whatever instrument was chosen for that event, so what actually appears is this cycle filtered through the instrumentation.

**Group** (element `series`, repetition `series`, repetitions 2–4) on the same group:

```
muted muted muted | normal | overtone1 overtone1 | bowing bowing bowing bowing
```

Now the modes are material. Three muted events establish a colour before it changes.

## Constraints

The mode must be playable by the instrument sounding it. With `Ins` before `Per` in the [hierarchy](fields/hierarchy) the constraint is tight — the specific chosen instrument's mode set. With `Per` before `Ins` it is the weaker achievability requirement that some instrument in the pool could play it, and the instrument choice is then narrowed to those that can. Where no admissible value exists, a wrong element is used and marked with a [comment](fields/comment).

Note that with [performance mode](fields/performance-mode) set to per-note, a separate value is drawn for every note of a chord, so the principle advances several times per entry point.

## Related

- [performance mode](fields/performance-mode)
- [performance table](fields/performance-table)
- [hierarchy](concepts/hierarchy)
