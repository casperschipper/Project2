# Registers

> The supply of pitch ranges REGISTER can choose from - each one either a range between two absolute pitches, or an explicit percussion entry.

A register is a range between two absolute pitches (octave + step), e.g. `1.01`–`5.12`. Once [harmony](fields/harmony-row) has decided a relative pitch, REGISTER's job is to place it inside whichever register was chosen here - searching the octaves the register spans for one where that relative pitch actually lands inside the range, and taking the lowest fit.

A **percussion** entry means "no pitch at all". Project Two's original convention marked this with a register of `(0,0)`; here it is a real, distinct kind of entry instead - it can never be confused with a very narrow but genuine pitch range, and an instrument marked [percussion](fields/instrument-pitch-range) can only ever be paired with one.

Registers may overlap freely, and the same relative pitch can fall in several of them at once - `301` and `303` both fall inside `3.01`–`5.12` as well as `1.01`–`3.12`, for instance. Which register is active for a given note is decided by the [ensemble](fields/register-ensemble) and [order](fields/register-order) principles below, exactly like every other parameter's list.

## Related

- [register table](fields/register-table)
- [instrument pitch range](fields/instrument-pitch-range)
- [harmony row](fields/harmony-row)
