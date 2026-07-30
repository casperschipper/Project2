# Transposition

> How the row is transposed each time it has been used up in full (TRANSP-ROW, entry 20).

This field only applies when [principle](fields/harmony-principle) is set to Row. Once every value in the [row](fields/harmony-row) has been distributed, the row is reused - transposed by some interval so the piece doesn't just repeat the same pitch sequence forever. This setting picks how that interval is chosen for each new pass:

- **None** - the row repeats completely unchanged, pass after pass.
- **Alea** - a fresh random interval is drawn for each pass.
- **Series** - every possible interval is used once before any repeats, the same discipline [series](concepts/series) applies elsewhere.
- **Chromatic** - each pass is transposed exactly one semitone further than the last (pass 1 unchanged, pass 2 up a semitone, pass 3 up two, and so on), wrapping back to unchanged once it has climbed through the whole octave division.
- **Serial** - the row itself is reused as the sequence of transposition intervals, so the row's own shape determines how it develops.

## Related

- [harmony principle](fields/harmony-principle)
- [row](fields/harmony-row)
