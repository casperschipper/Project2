# Duration list

> The supply of tone lengths, in seconds. A tone's duration is measured from its own entry point, so it decides where the tone stops, not when the next one starts.

Duration and [entry delay](fields/entrydelay-list) are calculated from the same time point but answer different questions. Entry delay says when the next attack arrives; duration says when this tone releases. The relationship between the two produces the articulation of the piece, and it is governed by the [duration relation](fields/duration-relation).

Two consequences follow automatically from the numbers, without your writing any rule:

- If a duration is **shorter** than its entry delay, silence appears between the release and the next attack — a *pseudo rest*. If another tone is still sounding across that gap, the rest is *concealed* and not heard.
- If a duration is **longer** than its entry delay, the tone is still sounding when the next attack arrives, and the texture accumulates.

So the relation between this list and the entry delay list determines whether your music is detached, seamless, or increasingly saturated. It is worth laying the two lists side by side when designing them.

## Example

```
index   0    1    2    3    4    5
value  0.1  0.2  0.3  0.5  0.8  5.0
```

Against an entry delay list running `0.1` to `0.8`, most of this list is comparable in scale and will produce a mixture of small gaps and small overlaps. The last value, `5.0`, is an outlier by an order of magnitude: a tone sounding through the next six to fifty attacks. Used sparingly it is a drone, a pedal, a change of level in the texture. Used with [alea](concepts/alea) at equal probability with the others, it will saturate the piece within seconds.

This is why the [order](fields/duration-order) principle matters so much here. The same list under [ratio](concepts/ratio) with `5.0` weighted at 1 against the others at 5 gives an occasional sustained tone under a predominantly detached surface — which is a compositional idea. Under alea it gives mud.

## Notes

- Values are in seconds; fractions such as `1/2` are accepted alongside decimals.
- Durations are further restricted by the playing instrument's own [duration range](fields/instrument-durations). A value outside every instrument's range sits in the list and can never sound.
- Under `equals-entry` this list is not consulted at all: the duration is the entry delay.

## Related

- [duration table](fields/duration-table)
- [duration relation](fields/duration-relation)
- [entry delay list](fields/entrydelay-list)
