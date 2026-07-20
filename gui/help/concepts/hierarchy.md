# Hierarchy

> The order in which parameters are resolved for each event. The first parameter chooses freely; every later one must live with what the earlier ones have already decided.

The parameters of a note — instrument, performance mode, dynamic, entry delay, duration — are not independent. A marimba cannot play `pizzicato`. A duration cannot be longer than its entry delay if you have asked for `shorter-than-entry`. A chord of four notes cannot be played by an instrument whose chord size is one. Something has to give, and the hierarchy is where you say what gives.

The **main parameter** is the one you place first. Its [selection principle](concepts/selection-principles) runs completely unencumbered: whatever you asked for, you get, event after event, exactly as designed. In exchange, it imposes conditions on everything after it. Every subsequent parameter draws under a predicate — "give me the next value in your cycle that is compatible with what has already been fixed here" — and the further down the list a parameter sits, the more conditions it is carrying.

This is a compositional decision, not a technical one. Putting instrument first produces a piece whose instrumentation is exactly as you specified and whose dynamics are whatever the instruments permit. Putting dynamics first produces a piece whose dynamic shape is exactly as you specified and whose instrumentation is bent to serve it. Both are defensible; they are different pieces.

## Conditioning versus achievability

There are two distinct kinds of constraint, and the difference matters.

**Conditioning** applies when the constraining parameter has *already been resolved* for this event. If instrument precedes dynamics, then by the time dynamics is drawn the instrument is known, and the dynamic must be one this specific instrument can play. This is a tight, exact restriction.

**Achievability** applies in the other direction. If dynamics precedes instrument, no instrument has been chosen yet — so the dynamic is restricted only to values that *at least one* instrument in the layer's pool could play. This is a weaker, forward-looking check: it does not guarantee the eventual instrument will match, it only avoids drawing a dynamic that is impossible for everybody.

The consequence is that early parameters are freer and later parameters are more exactly matched. Reversing the hierarchy does not merely reshuffle priorities; it changes which constraint is tight and which is loose.

## Example

Take the hierarchy `Ins → Per → Dyn → Ent → Dur`.

For each event: an instrument is drawn with no restriction at all. Say `marimba`, whose modes are `normal, bowing` and whose dynamics are `mf f ff fff`. Performance is now drawn from the performance ensemble, restricted to `normal` or `bowing` — if the ensemble happens to contain only `muted` and `pizzicato`, no admissible value exists and a *wrong element* is emitted with a [comment](fields/comment). Dynamics is then drawn restricted to `mf f ff fff`; a `pp` in the ensemble will simply be skipped over. Entry delay follows, then duration, which under `shorter-than-entry` must not exceed the entry delay just fixed.

Now reverse the first two: `Per → Ins → …`. Performance now draws freely — every mode you asked for appears in the score in exactly the proportions your principle produces. Instrument is then restricted to those instruments that can actually play the mode already chosen. The instrumentation becomes a *consequence* of the articulation, which is a genuinely different way to compose.

## Rules the program enforces

- **Per-note parameters need `Ins` first.** If [dynamics mode](fields/dynamics-mode), [performance mode](fields/performance-mode) or the [duration relation](fields/duration-relation) is set to per-note, the instrument must precede that parameter in the hierarchy — the number of notes in the chord is a property of the chosen instrument's chord size, so it must be known before per-note values can be drawn.
- **Instrument-derived density needs `Ins` first.** See [density](concepts/density).
- **Entry delay before duration** is required in practice whenever the duration relation is `equals-entry` or `shorter-than-entry` and you want the *entry delay* to be the free parameter. Place duration first instead and the relation is enforced the other way round: entry delays shorter than the chosen duration are rejected.

## Diagnosing trouble

A high rate of comments in the score is the symptom of a hierarchy that is asking too much of its lower parameters. The remedies, in order of how often they help: make the lower parameter's table groups broader; make the groups *compatible* with the upper parameter's groups (see [union and combination](concepts/union-and-combination), which exists precisely to guarantee this pairing); or move the over-constrained parameter higher and accept that something else will bend instead.

## Related

- [selection principles](concepts/selection-principles)
- [union and combination](concepts/union-and-combination)
- [hierarchy field](fields/hierarchy)
