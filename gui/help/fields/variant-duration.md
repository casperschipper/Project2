# Variant duration

> The intended length of the variant in seconds. It determines how many entry points are generated, not how long the result actually turns out to be.

The program divides the variant duration by the *average* entry delay of a layer's ensemble to estimate how many entry points that layer needs. It then produces that many events by accumulating entry delays one after another.

Because the entry delays are themselves chosen by a [selection principle](concepts/selection-principles) rather than averaged out, their sum does not necessarily land on the stated duration. A variant of 30 seconds may come out at 28.4 or 31.7. This is expected and is stated as such in the manual. The variant duration is a specification of scale, not a boundary the music is trimmed to.

All [layers](concepts/layers) of a variant share the same variant duration and the same metronome tempo. Since each layer computes its own event count from its own entry-delay ensemble, layers with fast vocabularies produce many more events than layers with slow ones over the same span — which is exactly how you get differentiated simultaneous strands.

## Example

Variant duration 30.0 s.

Layer A's entry-delay ensemble is `0.4 0.5 0.6`, average 0.5. Estimated events: 30 ÷ 0.5 = 60.

Layer B's entry-delay ensemble is `0.1 0.2 0.3`, average 0.2. Estimated events: 30 ÷ 0.2 = 150.

Both layers span roughly half a minute; one has 60 attacks and the other 150.

Now change nothing but the entry-delay ensemble principle to a [ratio](concepts/ratio) weighted heavily toward the longest value. The average rises, the estimated event count falls, and the same 30 seconds becomes a sparser piece — without your having touched the duration field at all.

## Practical notes

- To make a piece longer without making it denser, raise the variant duration. To make it denser without making it longer, shorten the entry delays.
- Very short variant durations combined with long entry delays can yield only a handful of events, which gives [series](concepts/series) and [tendency](concepts/tendency) too little room to express themselves. If a principle seems to have no audible effect, check the event count first.
- The value is a positive number of seconds; decimals are allowed.

## Related

- [entry delay list](fields/entrydelay-list)
- [layers](concepts/layers)
- [seed](fields/seed)
