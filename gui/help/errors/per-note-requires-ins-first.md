# A per-note parameter needs Instrument earlier in the hierarchy

This parameter is set to be chosen *per note*, but Instrument comes after it in the [hierarchy](concepts/hierarchy).

## Why this matters

Duration, dynamics and mode of performance can each be resolved in two ways. *Per chord* decides the value once for an entry point, so every tone starting there shares it. *Per note* decides independently for each tone, which is what lets a chord be voiced with different articulations or a spread of dynamics inside it.

Per note therefore needs to know how many notes there are, and that count is the chord size of the instrument playing the entry point. Until the instrument has been selected there is no chord size, and so no notes to distribute values across. A per-note parameter placed before Instrument would be asked to produce one value per note at a moment when the number of notes does not yet exist.

Per chord has no such requirement, because it produces a single value for the entry point regardless of how many tones eventually occupy it, which is why the ordering constraint appears only when you switch a parameter to per note.

## How to fix it

- Move Instrument earlier in the hierarchy, before this parameter. Everything after it may stay in its current relative order.
- Switch this parameter back to *per chord* if you want it to lead the piece and constrain the instrument choice rather than follow it.
- If several parameters are per note, Instrument must precede all of them, which in practice usually means placing it first. Note that [instrument density](instrument-density-requires-ins-first) requires exactly that anyway.
