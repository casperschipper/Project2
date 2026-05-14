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
`dune exec bin/main.exe`

# TODOS

[x] Union and combination
[x] Any problem that may occur return it as result.
[x] Implement autonomous density
[ ] Selection principles as sequences with more explicit context and state.

[ ] Hierarchy as a thing that can be computed from the current structure formula
[ ] Hierarchy as defined by the user. 

As things got complicated with the auto-density, I had a bit of help by claude (it got quite a bit confused as well together with me). But it produced compiling code, but it needs to be verified for sure:

sel_seq_gen_of_array n principle arr : (unit -> 'a) Seq.t — a sequence of n generators, one element per time point. The outer sequence drives "how many time points," and calling the generator multiple times stays at the same position:

  Alea — stateless, same gen closure for all time points, just picks randomly
  Series / Ratio — shared state ref, so the series continues where the previous time point left off. A last ref tracks the most recently yielded value; if the series row boundary happens to produce a repeat (first of new shuffle = last of old), it skips that value and advances — satisfying the no-cross-timepoint-repeat rule without disturbing within-time-point distinctness (which series already guarantees)
  Group / Sequence — shared state ref, no repeat guard needed (Group's repeat semantics are intentional; Sequence is a user-defined cycling order)
  Tendency — delegates directly to the already-existing tendency_mask_gen, which already returns (unit -> 'a) Seq.t with frozen lo/hi bounds per time point
  calculate_layer_autonomous_density — now uses sel_seq_gen_of_array. The fold threads gen_seq : (unit -> instrument) Seq.t through the accumulator; each iteration pops one generator with Seq.uncons and passes it to fill_to_density. fill_to_density is simpler — it just calls gen () repeatedly until the density target is met, no sequence threading required.




[ ] Define input as a runtime prompt?
[ ] Store input as a reusable file?
[ ] Implement another parameter x 
