# Instruments cannot use combination

The instrument parameter's ensemble is set to *combination*, which is not available to it.

## Why this matters

[Combination](concepts/combination) means: do not select your own groups, but adopt the sequence of group indices that the *instrument* parameter selected, and assemble your [ensemble](concepts/list-table-ensemble-order) from the groups at those same positions. It is how entry delays, durations, dynamics and performance can be tied to the instrumentation, so that group 2 of the dynamics table is understood to belong with group 2 of the instrument table.

The instrument parameter is the one everything else would be following. There is nothing above it for it to adopt, so combination has no meaning here; asking for it is asking the instruments to follow themselves.

This asymmetry is not an oversight but the structure of the design. Instrument is the reference parameter for group selection in the same way that it is the reference for chord size, and for [per-note](per-note-requires-ins-first) resolution, and for [instrument density](instrument-density-requires-ins-first). Something has to choose the groups first, and that something is the instrument parameter.

## How to fix it

- Choose *alea* for the instruments, and the groups will be drawn at random.
- Choose *series*, and every group will be used once before any repeats.
- Choose an explicit *sequence* of group positions if you want to control which groups appear and in what order.
- Then set the other parameters to combination if you want them to follow. That is the direction the relationship runs.
