# Structure formula

> The complete description the program reads in order to generate a variant: all your material, all your groupings, all your selection principles and all your constraints. Start here.

The structure formula is your side of the work. Everything you decide as a composer goes into it, and nothing else affects the result except the [seed](fields/seed). The manual calls it "the structural characteristics of the parameters and their items as expressed in the input data, rules for the selection of elements and for the hierarchy of the parameters" — in other words, not a piece but a specification of a piece.

The program reads it and produces a [variant](variant). Read it twice with the same seed and you get the same variant; read it with a different seed and you get another member of the same family. So the formula is best thought of as describing a *class* of pieces whose members share whatever you determined and differ wherever you left room.

## What it contains

**Global settings.** [Seed](fields/seed), [variant duration](fields/variant-duration) in seconds, and [octave division](fields/octave-division). Small in number, large in effect: seed selects which variant you hear, variant duration sets the scale from which each layer's event count is derived.

**The five parameters.** Instrument, entry delay, duration, dynamics and performance mode. Each is built the same way, through the four stages of [list, table, ensemble, order](list-table-ensemble-order): a flat list of every value you might use; a table whose rows are groups of [indices](indices) into that list; an ensemble principle that chooses which group becomes active; and an order principle that draws values from the active group in time. Two [selection principles](selection-principles) per parameter, one for each of the last two stages.

Instrument is the odd one out, because the instruments themselves carry properties — [chord size](fields/instrument-chordsize), [compass](fields/instrument-compass), which [dynamics](fields/instrument-dynamics) and which [performance modes](fields/instrument-performance) they can manage. Those properties are what the other parameters are later measured against.

**[Hierarchy](hierarchy).** The order in which the parameters are resolved for each event. The first is free and imposes conditions; every later one draws under the conditions already fixed. Reversing two entries produces a genuinely different piece, not a reshuffled one.

**[Union](union) and [combination](combination).** Two switches at the group level. Combination makes a parameter follow the instrument parameter's choice of groups instead of choosing its own. Union decides whether the selected groups are merged into a single pool — one [layer](layers) — or kept apart, one layer each. Together with [number of instrument groups](fields/number-of-instrument-groups) they determine the polyphonic shape of the variant.

**[Vertical density](vertical-density).** How many tones begin at each entry point: either a range plus a principle of its own, or derived from the chord size of whichever instrument is chosen.

**[Duration relation](duration-relation).** How a tone's duration relates to the entry delay that follows it, and whether a chord's notes share one duration or each get their own.

## How the pieces fit together

A useful way to hold it in mind:

1. The **lists** say what exists.
2. The **tables** say which subsets are musically coherent.
3. The **ensemble** principles say which subset is in force for this variant or this layer.
4. **Union and combination** say how many layers there are and how well matched their materials will be.
5. The **order** principles say in what succession the values arrive.
6. The **hierarchy** and the instrument definitions say what happens when those successions ask for something impossible.
7. **Density** and the **duration relation** turn the resulting stream of choices into actual sounding chords with actual lengths.

Points 6 and 7 are where formulas usually fail in practice. If a variant is full of comments — wrong elements marked in the score — the formula is asking a lower parameter for values its upper neighbours have already ruled out. See [hierarchy](hierarchy) for the diagnosis and the usual remedies.

## Working with a formula

Edit small and listen often. The most instructive single habit is holding the seed fixed while you change one thing, so that any difference you hear is attributable to the edit — and then, once the edit is settled, stepping through several seeds to check that what you gained holds across the family rather than in one lucky reading.

The formula plus the seed is a complete description of a result. Note both down for any variant you want to be able to recover.

## Where to go next

- [variant](variant) — what a single realisation is, and why there are many
- [list, table, ensemble, order](list-table-ensemble-order) — the chain every parameter passes through
- [selection principles](selection-principles) — the six behaviours
- [hierarchy](hierarchy) — how parameters constrain each other
- [union and combination](union-and-combination) — coupling and layering
- [layers](layers) — simultaneous strands
