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

[ ] Implement autonomous density
[ ] Define input as a runtime prompt?
[ ] Store input as a reusable file?
[ ] Implement another parameter x 
