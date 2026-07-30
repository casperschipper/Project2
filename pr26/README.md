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

* Although not in the spec: would it be useful to have a "bypass hierarchy" option per parameter? So that apart from the "primary" parameter in the hierarchy, another can also be fully expressed? It may be helpful just to see what the selection principle would be like without the restrictions.
* What is our policy on users having to provide dummy values? For example in harmony, where all "modes" need data, even if you always use only one mode, but also if entry=duration, then one of the users data is completely ignored. Apart from annoying, it may make it harder to read the structure formula. It also makes for "smelly" code when it is implemented like this.
* Proposal for dur: entry delay values are required, if you choose entry=dur, then duration is skipped. Drawback is that values of dur cannot be easily used as entry delays (which might have been useful?)



## Combination interface 

If we derive playable performance modes from instrument, and we link groups through combination, we could also check if the 
table groups are sane: does it include incompatible modes, that cannot be played by *any* instrument in the group?
Should the composer be helped in some way to construct useful tables? If a parameter is combined, it probably makes sense to also combine the construction of tables somewhat.

# TODOS



[ ] interval principle

# DONE


[x] registers in instrument definitions are made up of octave and relative pitch
(to be called like taht in the interface)
[x] Call compass "pitch range"
[x] register list, make either/or percussion/range visually clearer
[x] empty list field when saying "set list"
[x] maintaining state (selection cycles, harmony state etc) across layers and
variants in the "variant group"
[x] multiple variants
[x] test row transposition modes

[x] Fixed transposition in ROW mode
[x] Fixed performance per chord
[x] Total problems: be able to tell which user definition caused a problem.
[x] Implement another parameter x 
[x] Define input as a runtime prompt?
[x] Another question: how to deal with percussion? In manual both register and pitch can result in percussion.
[x] Hierarchy as a thing that can be computed from the current structure formula
[x] Hierarchy as defined by the user. 


chord 5 6 10

you go in both directions through the chord as a cyclical structure

5 to 6 -> 6 to 10
6 to 10 -> 10 to 5
10 to 5 -> 5 to 6
10 to 6 -> 6 to 5
6 to 5 -> 5 to 10
5 to 10 -> 10 to 6

interval matrix:
from Y-axis to X-axis

make circular interval visualization
visualize interval matrix as graph
auto consistency check for matrix

Done

[x] validation should collect as many errors as possible, not stop at first
[x] Implement autonomous density
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

[x] Define input as a runtime prompt?
[x] Another question: how to deal with percussion? In manual both register and pitch can result in percussion.
[x] Hierarchy as a thing that can be computed from the current structure formula
[x] Hierarchy as defined by the user. 

[x] Implement another parameter x 
[x] Total problems: be able to tell which user definition caused a problem.

[x] validation should collect as many errors as possible, not stop at first
[x] Implement autonomous density

