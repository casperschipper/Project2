[x] Dynamic list
[x] Sample is not a good name (changed to order)
[x] RATIO;
[x] factors apply to the list and is then "multiplied" by the occurance of the table
[x]  Throw (tr) from the autonomous density
[x]  Random seed in the sexp
[x] Hierarchy should be a total ordering of elements, no missing or duplicate allowed.
[x] There should be either a "combination" or a "group selection principle" defined for parameters, not both. So both can be included in the "principles" stanza and parsed as such.
[x] The duration extra "modes" should be included in the selector principles
[x] I think autonomous density should be more restricted: it should not be able to pick the same instruments many times?


Still to do:


[ ] Fractions in time parameters (dur/entrydelay)
[ ] track, group, entry, layer, instrument (be able to sort by that kind of thing)

Claude todo:

I read through the whole pipeline — selection.ml, score_generation.ml, parameters.ml, structure_formula.ml — and ran the default formula. The architecture is sound (the hierarchy fold, the Impossible tagging mechanism, per-tone vs per-chord threading all hang together well). But I found a few genuine conceptual issues, ordered by severity.

1. Tendency sampling goes out of bounds at the top of the range (crash)

tendency_sample (selection.ml:321) maps a unit value to an array index with no upper clamp:

arr.(lo +. Random.float (hi -. lo) |> ( *. ) (float_of_int l) |> floor |> int_of_float)

If a tendency window collapses to the top of the range — lo = hi = 1.0, which UnitFloat explicitly permits (tools.ml:9) — then Random.float 0.0 = 0.0, the value is 1.0, and the index becomes floor(1.0 * l) = l → out of bounds. A composer writing a mask that pins to the maximum (e.g. (start 1.0 1.0)) crashes the run. The fix is a min (l-1) clamp on the index. (tendency_peek and the inlined tendency branches in score_generation.ml:120,181 share the expression.)

2. DurEqualsEntry is silently violated by the instrument-max clamp

In the Dur step under DurEqualsEntry (score_generation.ml:387-392):

| DurEqualsEntry, Some (Entrydelay ed) ->
    let d = match proto.instrument with
      | Some (Instrument { durations = AllowedDurations { max; _ }; _ }) -> Float.min ed max
      | None -> ed in
    ( states, { proto with duration = Some (Shared (Duration d)); duration_ok = Some (Shared true) })

When the hierarchy runs Ins and Ent before Dur (e.g. (Ins Ent Dur …)) and the drawn entry delay exceeds the instrument's max duration, the duration gets capped below the entry delay — so duration ≠ entry delay, the very invariant the mode names. Worse, duration_ok is hard-coded to true, so it isn't flagged as IMPOSSIBLE. The other ordering (Dur before Ent) preserves equality, so the behavior is order-dependent in a way the mode's semantics shouldn't allow. Either flag it, or exclude out-of-range entry delays earlier when this mode is active.

3. Autonomous density consumes entry-delay draws it then throws away

In resolve_layer_autonomous, fill_group calls resolve_entry for every entry in a timepoint, and each one advances ed_state through the Ent step — but stamp_group_entrydelay (score_generation.ml:429) keeps only the last entry's delay and zeroes the rest. So for a group of size k, you burn k entry-delay draws and use one. Under Series/Sequence/Ratio (which are stateful and meant to express a distribution), the realized entry delays are a biased every-k-th subsample rather than the intended sequence. It also makes calculate_number_of_events' duration estimate drift. Conceptually, the entry delay for a shared timepoint should be drawn once per timepoint, not once per entry.

4. Autonomous density can trim below an instrument's declared minimum chord size

fill_group (score_generation.ml:467) caps the last pick with nr_of_tones = Some (n - (total' - target)). If the target is reached mid-chord, an instrument declared (chordsize 4 6) can be emitted with 1–2 tones, silently overriding its own minimum. (And if low = 0 were ever allowed, this yields a zero-tone entry.) That may be an acceptable design choice, but right now it's implicit — your own notes flag "autonomous density should get more trouble," so worth deciding deliberately.

5. Minor: dead, inconsistent tendency code + stale example files

- tendency_draw_predicate (selection.ml:347) and tendency_peek (selection.ml:345) are never called (the predicate path is inlined in score_generation.ml). If tendency_draw_predicate ever were wired in, it rebuilds state via tendency_mk_state, which resets the mask to position 0 on every draw — inconsistent with the inlined version that advances. I'd delete both to avoid a future trap.
- formula1.sexp and formula.sexp.backup no longer load: they lack the now-required (seed …) field and give only a 3-element (hierarchy (Ins Dyn Per)), which mk_hierarchy rejects (it demands a full permutation of all five). Only formula.sexp is current.