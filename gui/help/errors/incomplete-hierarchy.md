# The hierarchy is missing a parameter

Not every parameter appears in the [hierarchy](concepts/hierarchy). The message names which ones are absent.

## Why this matters

The hierarchy is the plan for building a tone. Project Two resolves the parameters one after another in the order you give: it decides the instrument, the entry delay, the duration, the dynamic and the mode of performance, each within the conditions the earlier decisions have set. Every parameter must appear exactly once, because each position in the ordering is the step at which that parameter is actually resolved. A parameter with no position in the hierarchy never gets a step, and so a tone would reach the score with that property undecided.

This is not a formality that could be papered over with defaults. The whole point of the hierarchy is that the earlier a parameter sits, the freer it is and the more it constrains those after it. A parameter without a place has no relationship to the others at all, and there is no defensible guess about where it would have gone.

## How to fix it

- Add the missing parameters. Every one of Instrument, Entry delay, Duration, Dynamics and Performance must be present.
- Think about placement rather than just appending. A parameter you care about most, and want to move most freely, belongs early; a parameter you are willing to have squeezed by the others belongs late.
- Check the constraints that come with certain settings: [instrument density](instrument-density-requires-ins-first) and [per-note parameters](per-note-requires-ins-first) both require Instrument to come first or early, and a [duration measured against the entry delay](duration-needs-entry-first) requires Entry delay before Duration.
