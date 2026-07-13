# Projekt Two - G.M. Koenig (2026 implementation)

This is the current in-progress version of an implementation of PR2.
It is based (mostly) on the Atari Manual.

Currently, it implements the selection principles and runs some tests on the entry delay parameter.

## Requirements:

* opam (version used 2.5.0)
* dune (version used 3.22)
* ocaml (version used 5.4.1)

But probably it will work for more recent versions as well.

## Building & running

You should be able to run it with:

`dune build`  
`dune exec bin/main_sexp.exe` 
This uses the formula.sexp

# Questions

* Do we allow random hierarchy? I found that allowing it really changes what input would work at all. In general, finding an input that "works" is hard, but with random hierarchy, all bets are off.
* Although not in the spec: would it be useful to have a "bypass hierarchy" option per parameter? So that apart from the "primary" parameter in the hierarchy, another can also be fully expressed? It may be helpful just to see what the selection principle would be like without the restrictions.
* What does page 81 in the duration chapter actually say. Is it just stating something obvious, or something deeply weird?
* How do we implement the time point generation?
* What is our policy on users having to provide dummy values? For example in harmony, where all "modes" need data, even if you always use only one mode, but also if entry=duration, then one of the users data is completely ignored. Apart from annoying, it may make it harder to read the structure formula. It also makes for "smelly" code when it is implemented like this.
* Proposal for dur: entry delay values are required, if you choose entry=dur, then duration is skipped.



## Combination interface 

If we derive playable performance modes from instrument, and we link groups through combination, we could also check if the 
table groups are sane: does it include incompatible modes, that cannot be played by *any* instrument in the group?
Should the composer be helped in some way to construct useful tables? If a parameter is combined, it probably makes sense to also combine the construction of tables somewhat.

# TODOS

[x] Union and combination
[x] Any problem that may occur return it as result.
[x] Implement autonomous density
[x] Selection principles as sequences with more explicit context and state.
[x] Wire in the new selection principles
[x] modes of performance. in the instrument definition, the possible modes of
performance of each instrument is given as a string, so each instrument contains
one set of strings
from these definitions the list of performance modes in the performance
parameter is constructed (which cannot be edited by the user), but they can be
arranged in the table (via indices). these prevents incoherence between
instrument definition and performance parameter and simplifies entry
[x] rewrite selection principles as exposing state in struct + next function
(giving n values needed) and a function for getting possible next values (and
being able to prohibit/filter), instead of unit seq, we give it a context, they
output results, there may be no possible value

[ ] Define input as a runtime prompt?
[ ] Another question: how to deal with percussion? In manual both register and pitch can result in percussion.
[/] Hierarchy as a thing that can be computed from the current structure formula
[/] Hierarchy as defined by the user. 

[x] Implement another parameter x 
[ ] Total problems: be able to tell which user definition caused a problem.

Done

[x] validation should collect as many errors as possible, not stop at first
[x] Implement autonomous density


Motivation of fold:
Outer fold (calculate_layer_hierarchical): List.fold_left apply_step (protos, init_states) hierarchy walks the 3-element hierarchy list (e.g. [Ins; Dyn; Per]). Each step processes all proto-events for the layer before moving to the next hierarchy element. So the hierarchy order determines which field gets filled in across the whole layer first.

Inner fold (inside each apply_step case): List.fold_left_map walks over every proto_event in the layer, threading the relevant sel_state (here dyn_state) through each draw — this is what makes Series/Sequence-style principles advance correctly across the whole layer rather than resetting per event.

For the selected Dyn case specifically:

For each proto pe, build a predicate d : Dynamic.t -> bool:

If pe.instrument is already Some (meaning Ins ran before Dyn in the hierarchy) → restrict d to that specific instrument's dynamics set. This is the "conditioning" — the dynamic must be playable by the instrument already chosen for this event.
If pe.instrument is None (meaning Dyn runs before Ins) → restrict d to dynamics playable by at least one instrument in states.instr_arr (the instrument pool for this layer). This is a weaker, "achievability" constraint — it just ensures that whatever dynamic gets picked, some instrument later could still satisfy it.
sel_draw_pred pred st draws a value from dyn_state (initialized from dyn_arr/dyn_principle) restricted to pred, returning (v, st').

The proto is updated to { pe with dynamic = Some v }, and st' becomes the new threaded dyn_state for the next proto.

After the fold, (filled, { states with dyn_state = dyn_state' }) is returned — filled is the layer's protos with dynamic now set, and the updated dyn_state' carries forward into the next hierarchy step (though Dyn's own step doesn't need to be revisited).

With the new [Ins; Dyn; Per] order in main.ml: Ins runs first (unconstrained, since pe.performance and pe.dynamic are both None at that point — apply_step's Ins predicate is Fun.const true). Then Dyn runs with pe.instrument = Some _, so it's tightly constrained to that instrument's allowed dynamics. Then Per runs similarly, constrained to that instrument's allowed performances. So instrument selection drives both performance and dynamic selection — the opposite of the earlier [Dyn; Per; Ins] order, where Dyn/Per were picked first under the looser "achievable by some instrument" predicate, and Ins then had to satisfy both.