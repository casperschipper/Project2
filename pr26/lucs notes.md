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
[x] Fractions in time parameters (dur/entrydelay)
[x] Tendency sampling goes out of bounds at the top of the range (crash)
[x] Solved a problem with entrydelay, entry and note, that caused entrydelays to be thrown away.


Still to do:


[ ] track, group, entry, layer, instrument (be able to sort by that kind of thing)

Claude todo:

[ ] Minor: dead, inconsistent tendency code + stale example files

- tendency_draw_predicate (selection.ml:347) and tendency_peek (selection.ml:345) are never called (the predicate path is inlined in score_generation.ml). If tendency_draw_predicate ever were wired in, it rebuilds state via tendency_mk_state, which resets the mask to position 0 on every draw — inconsistent with the inlined version that advances. I'd delete both to avoid a future trap.
- formula1.sexp and formula.sexp.backup no longer load: they lack the now-required (seed …) field and give only a 3-element (hierarchy (Ins Dyn Per)), which mk_hierarchy rejects (it demands a full permutation of all five). Only formula.sexp is current.