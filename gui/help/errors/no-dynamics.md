# This instrument has no dynamics

An instrument was defined without any dynamics, so it can never be given a tone.

## Why this matters

Dynamics are a [parameter](concepts/hierarchy) in Project Two, resolved for each tone or each chord from the piece's own dynamics [list, table and ensemble](concepts/list-table-ensemble-order) according to a [selection principle](concepts/selection-principles). Every tone that reaches the score has one.

Each instrument then declares which of those dynamics it can realise. The subset is meaningful: an instrument may have a genuinely restricted dynamic range, and stating that in the formula lets the program route material accordingly rather than writing something unplayable. When a dynamic has been drawn and this instrument is a candidate, the dynamic must be within its declared set; if nothing suitable can be found, the tone is marked as a *wrong element* with a comment in the score.

An instrument with no dynamics fails that test unconditionally. It can be selected by the instrument parameter, occupy an entry point, and then never legally sound. Since the failure appears in the score as comments rather than as a missing player, it is easy to misread as a problem elsewhere in the formula.

## How to fix it

- Give the instrument the dynamics it can produce. Listing all of the piece's dynamics is entirely normal for an unrestricted instrument.
- Every dynamic you name must appear in the piece's master dynamics list, or it will be reported as an [unknown dynamic](unknown-dynamic).
- Keep the restriction genuine. Narrowing the dynamics of the piece as a whole belongs in the dynamics [table](concepts/list-table-ensemble-order), not in each instrument.
