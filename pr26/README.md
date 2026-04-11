# Projekt Two - G.M. Koenig (2026 implementation)

This is the current in-progress version of an implementation of PR2.
It is based (mostly) on the Atari Manual.

Currently, it implements the selection principles and runs some tests on the entry delay parameter.

## Requirements:

* opam (version used 2.5.0)
* dune (version used 3.22)
* ocaml (version used 5.4.1)

for midi output (not implemented yet)  
* jack2 / jacklib (1.9.22)

But probably it will work for more recent versions as well.

## Building & running

You should be able to run it with:

`dune build`  
`dune exec bin/main.exe`
