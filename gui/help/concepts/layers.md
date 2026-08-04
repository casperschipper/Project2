# Layers

> A layer is one musical strand: a stream of entry points whose parameter values all come from one stockpile, drawn in chronological order by that stockpile's selection principles.

A layer is the unit of coherence in PROJECT TWO. Within a layer, entry delays come from one entry-delay ensemble, dynamics from one dynamics ensemble, instruments from one instrument ensemble, and each of these is read by a single [selection principle](concepts/selection-principles) whose state runs continuously from the beginning of the variant to the end. Whatever guarantees a principle offers — that `series` will use everything, that `tendency` will describe an arc — hold *within a layer*, and not across layers.

A layer is based either on a single group from the ensemble or on the [union](fields/union) of several groups. Union merges everything into one pool and therefore always yields exactly one layer. Without union, each group in the instrument ensemble becomes its own layer, so [number of instrument groups](fields/number-of-instrument-groups) is effectively the number of layers - this is true of both "without union" settings, `none` and `common-harmony`; they form layers identically and differ only in whether HARMONY is one of the things each layer does independently (see [union](fields/union) for that distinction).

Layers are simultaneous, not consecutive. All layers of a variant share the same [variant duration](fields/variant-duration) and the same metronome tempo, and each independently fills that duration with its own succession of entry points. In the printed parts each layer is still written out as its own block; conceptually they remain separate musics that happen at the same time - `common-harmony` is the one exception that ties their *pitches* back together across that separation, without touching anything else about how they're printed or timed.

## Layers and instrument groups

Without union (either sub-setting), the correspondence is direct: one instrument group, one layer. The layer's instrumentation is exactly the instruments named in that group.

What the *other* parameters contribute to each layer depends on [combination](concepts/union-and-combination):

- **With combination**, a layer's dynamics, durations, entry delays and performance modes come from the table rows matching its instrument group. Each layer is a matched set. This is how you give layers distinct characters.
- **Without combination**, each non-instrument parameter selects a single group per variant, and every layer works from that same group. The layers differ in instrumentation but share their rhythmic and dynamic vocabulary.

## Example

Instrument table with three rows; number of instrument groups = 2; union set to `none`; combination on for entry delay.

Ensemble selection picks instrument rows 1 and 2, so two layers arise.

**Layer A** — instrument group 1: `guitar1` alone. Its entry delays come from entry-delay group 1, say `0.4 0.5 0.6`, read with `series`. Roughly 30 s ÷ 0.5 s ≈ 60 entry points.

**Layer B** — instrument group 2: `piano`, `basedrum`. Its entry delays come from entry-delay group 2, say `0.1 0.2 0.3`, read with `series`. Roughly 30 s ÷ 0.2 s = 150 entry points.

The two run concurrently over the same 30 seconds: a sparse guitar layer against a rapid piano-and-drum layer. Note that the number of entry points is estimated per layer from that layer's own average entry delay, so layers with different vocabularies have genuinely different event densities. Combined with per-layer [density](concepts/density), this is the main way to get contrapuntal weight into a variant.

## Practical consequences

- If you want polyphony in the sense of independent simultaneous strands, do **not** use union - pick `none` for fully independent layers, or `common-harmony` if you want them independent in everything except pitch.
- A `sequence` or `tendency` placed on a parameter behaves independently in each layer — two layers on the same tendency will trace the same arc but sample it at different rates, because their event counts differ. Under `common-harmony`, HARMONY is the one exception: it doesn't run per layer at all, so this doesn't apply to it - see [union](fields/union).
- Comments (wrong elements) are local to a layer. A layer whose instrument group and dynamics group do not match will produce them steadily while its neighbour produces none.

## Related

- [union and combination](concepts/union-and-combination)
- [density](concepts/density)
- [number of instrument groups](fields/number-of-instrument-groups)
- [harmony principle](fields/harmony-principle)
