# Row

> The fixed sequence of relative pitches HARMONY distributes over entry points, one per note - always, regardless of how many notes share an entry point. `p` marks an explicit percussion event.

This field only applies when [principle](fields/harmony-principle) is set to Row - the simpler of the two implemented "row principles" for HARMONY (the manual's HARMONY parameter has three - CHORD, ROW and INTERVAL - and CHORD is out of scope here; see [principle](fields/harmony-principle)). Unlike performance, dynamics, duration and register, ROW has no "per chord" option: every note in a chord always takes its own next value from the row, ignoring the entry point entirely (a genuinely shared-per-chord harmony would be the CHORD principle, not built yet). The row is written once, as relative pitches from 1 to the [octave division](fields/octave-division), and gets used up in order; once every value has been distributed, the whole row is transposed as a unit and the cycle begins again - see [transposition](fields/harmony-transposition).

A `p` in the row is a genuine percussion event written directly into the sequence - a real, explicit value rather than a numeric stand-in (the original PR-2 convention overloaded relative pitch `0` for this; here it's its own distinct entry, distinct from a register's own [percussion entry](fields/register-list)). Whichever comes first in the [hierarchy](fields/hierarchy) between REGISTER and HARMONY decides which one forces the other: if HARMONY runs first and produces `p` here, the note must resolve to the percussion register; if REGISTER runs first and picks its percussion entry, HARMONY is forced to `p` regardless of what the row would otherwise have given.

The relative pitch alone does not fix an absolute pitch - it only fixes the *step within an octave*. Which octave it lands in is REGISTER's job (see [registers](fields/register-list)): the same row value can end up at different absolute pitches depending on which register is active when the note is resolved.

## Related

- [harmony principle](fields/harmony-principle)
- [transposition](fields/harmony-transposition)
- [registers](fields/register-list)
