# An instrument's duration range is inverted

The shortest duration declared for this instrument is longer than its longest.

## Why this matters

The two limits describe the band of durations this player can realise, and Project Two treats them as a filter over the values drawn from the [duration ensemble](concepts/list-table-ensemble-order). A tone whose duration falls inside the band can be given to this instrument; one outside it cannot, and the program either finds another way or marks the tone with a *comment* in the score.

If the minimum is above the maximum, the band is empty. Every duration is rejected, so this instrument can never be assigned a tone. That is unlikely to be what you meant, and the resulting variant would be full of comments or would quietly route everything to the other players, which is very hard to diagnose from the score alone.

## How to fix it

- Swap the two values if you entered them in the wrong order.
- Check the notation: these fields accept decimals and fractions alike, so `0.5` and `1/2` are the same value, but `1/2` and `1.2` are not, and the second is a common slip.
- If the instrument really should play only one duration, write the same value twice. That is a valid range of width zero.
