# Durations measured against the entry delay need Entry delay first

The duration relation is set to *shorter than entry*, but Entry delay comes after Duration in the [hierarchy](concepts/hierarchy).

## Why this matters

There are three ways duration can relate to entry delay. It can be *independent*, drawn from its own [ensemble](concepts/list-table-ensemble-order) with no reference to the rhythm. It can *equal* the entry delay, giving a seamless legato in which each tone lasts exactly until the next. Or it can be *shorter than* the entry delay, so that every tone stops before the next entry point and a gap opens after it, which the manual calls a *pseudo rest*. That third relation is one of the main ways articulated, detached textures are made in Project Two.

"Shorter than" is a comparison, and it needs both quantities. The manual describes it symmetrically: whichever parameter is decided first constrains the other. If entry delay comes first, durations exceeding it are rejected from the duration ensemble; if duration comes first, entry delays smaller than it are rejected instead. This program implements the first of those, so it needs the entry delay to be already known when the duration is chosen.

That makes the [hierarchy](concepts/hierarchy) order load-bearing here. Placing Duration before Entry delay would ask for a duration shorter than a number that does not yet exist.

## How to fix it

- Move Entry delay before Duration in the hierarchy.
- Switch the relation to *independent* if you want Duration to lead and to constrain the rhythm rather than follow it. Overlaps and rests then arise from the two lists rather than from a rule.
- Switch to *equals entry* if you wanted a continuous texture with no gaps; that relation needs no comparison and imposes no ordering.
