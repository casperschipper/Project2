august 31 2026

is it true that autonomous density of 4 means we need 4 instruments? i get that
warning


i want smart fomus-like tuplet quantization. we could generate lilypond, we
might need clef transposition, number of systems etc as optional in instrument
definition, possibly even package lilypond as a lib if not installed
osc output is promptable, maybe as supercollider osc score

[x] i want font size adjustable
[x] the "placeholder values" should probably be italicized, it is visually difficult to
differentiate
output width can be wider, i get unconformtable line breaks
[x] why do we need to define number of instrument groups? isnt that just the number
of rows in the table?
depending on number of instrument groups and combination/union setting gui
should diplay some inf
[x] if duration = entry delay that should be mentioendi n the hierarchy
of its block
[x] visualize tendency mask? can we see what the percentages mean in terms of the
values? (e.g. in vertical density)
[x] warning mouseover can be hidden by/below something above it if it is topmost row
[x] in instrument relative pitch can exceed octave division. is that correct?
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


# GUI notes

[ ] 0 or 1 based indexing of tables and other things
[ ] notes, 
[ ] named instrument groups


Still to do:


[ ] track, group, entry, layer, instrument (be able to sort by that kind of thing)

Claude todo:

[ ] Minor: dead, inconsistent tendency code + stale example files

- tendency_draw_predicate (selection.ml:347) and tendency_peek (selection.ml:345) are never called (the predicate path is inlined in score_generation.ml). If tendency_draw_predicate ever were wired in, it rebuilds state via tendency_mk_state, which resets the mask to position 0 on every draw — inconsistent with the inlined version that advances. I'd delete both to avoid a future trap.
- formula1.sexp and formula.sexp.backup no longer load: they lack the now-required (seed …) field and give only a 3-element (hierarchy (Ins Dyn Per)), which mk_hierarchy rejects (it demands a full permutation of all five). Only formula.sexp is current.
