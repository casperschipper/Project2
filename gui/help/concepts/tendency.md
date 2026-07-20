# Tendency

> A window that travels across the ensemble over the course of the variant. Values are drawn from wherever the window currently is, so the parameter drifts in a stated direction.

`Tendency` is the principle for *processes*: getting faster, opening from a narrow band to a wide one, converging on a register. Everything else in PROJECT TWO is stationary — the statistics of [alea](concepts/alea), [series](concepts/series) or [ratio](concepts/ratio) are the same at the beginning and the end of a variant. `Tendency` is the one principle that has a beginning and an end.

It works positionally. The ensemble is treated as a line running from 0.0 (its first element) to 1.0 (its last), so the *order in which you wrote the group* is now musically load-bearing — normally it is not. At each event a window `[low, high]` is open on that line and a value is drawn from inside it. Across the variant the window's two edges interpolate from their start values to their end values. A narrow window that moves is a glissando of vocabulary; a window that starts narrow and ends wide is a gradual opening-out; a window that stays put is just a restricted `alea`.

You describe this as one or more **sections**. Each section has:

- **portion** — its share of the variant's events, relative to the other sections' portions.
- **start min / start max** — the window at the section's beginning, as positions from 0.0 to 1.0.
- **end min / end max** — the window at the section's end.

Several sections let you build a shape with corners: expand, hold, then contract.

## Example

Entry delay ensemble, written deliberately in order:

```
position  0.00  0.14  0.29  0.43  0.57  0.71  0.86  1.00
value     0.1   0.2   0.3   0.4   0.5   0.6   0.7   0.8
```

One section, portion 1.0, start `0.5 0.5`, end `0.0 1.0`.

The window begins as a single point in the middle of the list — every event at the start of the variant uses roughly `0.4`–`0.5`. It then widens in both directions until, at the end, it spans the whole list. The result is a passage that begins as an almost even pulse and gradually disintegrates into a range from very short to very long. Nothing else in the program will do this.

Reverse it — start `0.0 1.0`, end `0.5 0.5` — and you get the opposite: a wide, irregular opening that funnels into a steady pulse.

Two sections give a shape:

```
section 1   portion 2.0   start 0.0 0.2   end 0.6 1.0
section 2   portion 1.0   start 0.6 1.0   end 0.9 1.0
```

Two thirds of the variant open out from the short values to the full range; the final third closes onto the long end. Note that section 2's start matches section 1's end — matching them makes the join smooth, deliberately mismatching them makes it a cut.

## Practical notes

- Because `tendency` is positional, **sort your list** if you want the process to be monotonic. A tendency over an unsorted list of durations produces a moving *selection* but not a moving *tempo*, which is occasionally what you want and usually not.
- The window edges are positions, not values. `start 0.5 0.5` means "the middle element", whatever value happens to sit there.
- Under a [hierarchy](concepts/hierarchy) constraint, the admissible elements are filtered first and the window is applied to what remains, so the tendency shape is preserved but compressed onto a smaller supply.

## Related

- [selection principles](concepts/selection-principles)
- [group](concepts/group) — persistence without direction
