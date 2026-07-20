# Performance list

> The master list of modes of performance. It is derived automatically from your instrument definitions and cannot be edited here.

Every instrument names the articulations it commands — see [instrument performance modes](fields/instrument-performance). This list is the union of all of them: every mode that appears on at least one instrument, and nothing else. It is maintained for you and shown read-only.

## Why it is read-only

Because a hand-written master list can contradict the instruments, and there is no good outcome when it does.

If you could type a mode here that no instrument possesses, it would be a value that enters tables and ensembles, gets drawn by a [selection principle](concepts/selection-principles), and can never be realised — every occurrence rejected under the [hierarchy](concepts/hierarchy) and marked with a [comment](fields/comment). The formula would appear to specify something it structurally cannot produce.

If you could omit a mode that an instrument does possess, the reverse happens: a capability you defined would be silently unavailable to the piece, and no diagnostic would tell you, because nothing is technically wrong.

Deriving the list makes both situations impossible. The instrument definitions are the single source of truth about what can be played, and the master list follows from them by construction. It also removes a whole class of typing errors — a mode spelled `pizzicato` on one instrument and `pizzicatto` on another would otherwise become two distinct values.

## How to change it

Edit the instruments. Adding `harmonic` to any instrument's mode set adds `harmonic` to this list; removing it from the last instrument that has it removes it from the list, and from the piece.

## Example

```
guitar1     normal, muted, overtone1
guitar2     normal, muted, overtone1
piano       normal, pizzicato
basedrum    normal, bowing
marimba     normal, bowing
```

The derived list:

```
index   0        1       2          3           4
value  normal   muted   overtone1  pizzicato   bowing
```

Five modes, in stable positions, which is what the [performance table](fields/performance-table) names with its [indices](concepts/indices). Note how unevenly they are distributed: `normal` is universal, `muted` and `overtone1` belong to two instruments, `pizzicato` and `bowing` to one and two respectively. That distribution is the real constraint on the performance parameter, and reading it here is a quick way to see how much freedom this parameter has before you write a single table row.

## Related

- [instrument performance modes](fields/instrument-performance)
- [performance table](fields/performance-table)
