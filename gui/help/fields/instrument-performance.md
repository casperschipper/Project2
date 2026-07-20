# Instrument performance modes

> The modes of playing this instrument commands. A performance mode can only be assigned to a tone if the instrument playing it has that mode.

Each instrument names the articulations available to it — `normal`, `muted`, `pizzicato`, `overtone1`, whatever vocabulary your piece uses. These names are yours to invent; the program attaches no meaning to them beyond identity. What matters compositionally is *which instruments share which modes*, because that sharing determines how freely the [performance](fields/performance-list) parameter can move.

The union of every instrument's modes is what forms the master [performance list](fields/performance-list), which is why that list is derived rather than typed. Adding a mode here makes it available to the whole formula; removing the last instrument that uses a mode removes it from the piece entirely.

## Example

```
guitar1     normal, muted, overtone1
guitar2     normal, muted, overtone1
piano       normal, pizzicato
basedrum    normal, bowing
marimba     normal, bowing
```

Read the sharing pattern rather than the rows. `normal` is universal — it can be drawn at any moment for any instrument and will never cause a conflict. `muted` and `overtone1` belong to the guitars alone; `bowing` to the percussion; `pizzicato` to the piano alone.

Under a hierarchy beginning with `Ins`, this means a `pizzicato` in the performance ensemble is realisable only when the piano happens to be chosen — and if the active instrument group does not contain the piano at all, `pizzicato` becomes unreachable in that [layer](concepts/layers) and every attempt produces a [comment](fields/comment).

Reverse the two — put `Per` before `Ins` — and the same data behaves very differently. Now `pizzicato` is drawn freely and the instrument choice collapses to the piano whenever it appears. The articulation is composing the instrumentation.

## Practical advice

Distinctive modes are expressive precisely because they are restrictive; that is the point of writing them. But keep at least one mode shared widely across the instrument list, so that every layer always has something safe to fall back on. A formula where no mode is common to all instruments will produce comments steadily under almost any hierarchy.

When you use [combination](concepts/union-and-combination), match the performance table rows to the instrument table rows so that each group's modes are playable by that group's instruments. This is the intended way to prevent conflicts by design rather than by filtering.

All names used here must be spelled consistently across instruments; the interface treats them as distinct if they differ.

## Related

- [performance list](fields/performance-list)
- [performance table](fields/performance-table)
- [hierarchy](concepts/hierarchy)
