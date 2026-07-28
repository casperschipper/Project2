# Instruments

> The list of instruments available to the piece, each described by what it can actually do: how many notes at once, what range, what durations, what articulations, what dynamics.

This is the [list](concepts/list-table-ensemble-order) for the instrument parameter — the supply from which the [instrument table](fields/instrument-table) forms groups. But it carries more than names. Each entry is a small description of an instrument's capabilities, and those capabilities become constraints on every other parameter through the [hierarchy](concepts/hierarchy).

That is the conceptual point worth grasping early. Elsewhere in PROJECT TWO a list is just material. Here it is also a set of rules. When you write that the marimba plays only `normal` and `bowing`, you are not describing an instrument for the reader's benefit — you are telling the program that a marimba event can never carry a `pizzicato`, and every draw of the performance parameter after `Ins` will respect that.

Each instrument has:

- **name** — how it appears in the score.
- **[chord size](fields/instrument-chordsize)** — minimum and maximum simultaneous tones.
- **[pitch range](fields/instrument-pitch-range)** — lowest and highest playable pitch.
- **[durations](fields/instrument-durations)** — the shortest and longest tone it can sustain.
- **[performance](fields/instrument-performance)** — the modes of playing it commands.
- **[dynamics](fields/instrument-dynamics)** — the intensities available to it.

## Example

```
guitar1     chordsize 6-6     normal, muted, overtone1     p mf f ppp
guitar2     chordsize 1-6     normal, muted, overtone1     p mf f ff
piano       chordsize 1-10    normal, pizzicato            ppp ... fff
basedrum    chordsize 1-1     normal, bowing               ppp ... fff
marimba     chordsize 1-4     normal, bowing               mf f ff fff
```

Read this as a set of constraints and the piece already has a shape. `guitar1` is fixed at six notes — it never plays a single line, only full chords. `basedrum` is fixed at one. The marimba cannot play quietly; the guitars cannot play loudly. Under a hierarchy beginning with `Ins`, a soft passage will therefore drift toward guitars and piano without your having asked for that anywhere, and a loud one toward marimba and drum. The instrumentation composes the dynamics.

Note that `bowing` here is assigned to bass drum and marimba, and `pizzicato` to piano. The mode names are yours to define; nothing constrains them to conventional usage. What matters is which instruments share them, because that sharing is what makes the [performance](fields/performance-list) parameter's values reachable.

## Practical advice

Give your instruments *overlapping* capabilities unless you have a reason not to. If each instrument commands a private set of modes and dynamics, then every parameter drawn after `Ins` has almost no freedom, and every parameter drawn before it becomes almost unsatisfiable — you will see a great many [comments](fields/comment). Some overlap is what keeps the formula alive.

The instrument's own performance and dynamics entries must be drawn from the master [performance list](fields/performance-list) and master dynamics list; the interface reports unknown names as errors.

## Related

- [instrument table](fields/instrument-table)
- [hierarchy](concepts/hierarchy)
- [density](concepts/density)
