# The lowest density is below one

The autonomous [vertical density](concepts/vertical-density) range has a minimum smaller than 1.

## Why this matters

Vertical density is the number of tones that begin together at an entry point. Under *autonomous* density you declare a range, and Project Two draws a density from it for each entry point according to a [selection principle](concepts/selection-principles), independently of what the instruments' chord sizes happen to be.

An entry point exists precisely because something starts there. A density of 0 would define an entry point at which nothing begins, which is not a rest but a contradiction: rests in Project Two are made in other ways, either as a duration shorter than its entry delay, which the manual calls a *pseudo rest*, or as autonomous rests inserted into the rhythmic context. Density is not the parameter for silence. Its lowest meaningful value is one tone, which gives you a monophonic texture.

## How to fix it

- Set the low bound to `1`. A range of `1` to `1` gives a strictly single-voiced texture.
- For a texture that varies between thin and thick, give a real range such as `1 4`, and choose the selection principle that shapes how it moves; a [tendency mask](concepts/selection-principles) is the natural choice if you want the density to drift over the [variant](concepts/variant).
- If you wanted silence at some entry points, work with the [duration relation](concepts/duration-relation) instead, letting durations fall short of their entry delays.
