# Transposition

> How the row is transposed each time it has been used up in full (TRANSP-ROW, entry 20).

Once every value in the [row](fields/harmony-row) has been distributed, the row is reused - transposed by some interval so the piece doesn't just repeat the same pitch sequence forever. This setting picks how that interval is chosen for each new pass:

- **None** - the row repeats completely unchanged, pass after pass.
- **Alea** - a fresh random interval is drawn for each pass.
- **Series** - every possible interval is used once before any repeats, the same discipline [series](concepts/series) applies elsewhere.
- **Chromatic** - the intervals ascend in a fixed sequence, one step further each pass.
- **Serial** - the row itself is reused as the sequence of transposition intervals, so the row's own shape determines how it develops.

## Related

- [row](fields/harmony-row)
