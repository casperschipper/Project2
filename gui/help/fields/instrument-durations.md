# Instrument durations

> The shortest and longest tone this instrument can produce, in seconds. Durations drawn for this instrument are restricted to that range.

Every instrument has physical limits on how long a sound can last. A struck bass drum cannot be sustained for five seconds; a bowed string cannot articulate a tone lasting five milliseconds. This pair of numbers records those limits, and the program enforces them.

The enforcement runs through the [hierarchy](concepts/hierarchy). If `Ins` precedes `Dur`, the instrument is already fixed when the duration is drawn, so the [duration ensemble](fields/duration-ensemble) is filtered to values inside this range and the first admissible one is taken. If `Dur` precedes `Ins`, the duration is drawn freely and the instrument choice is then restricted to instruments that can sustain it.

Either way, if no admissible value exists, a wrong element is used and the score carries a [comment](fields/comment) at that point.

## Example

```
guitar1    durations 0.1 to 4.0
basedrum   durations 0.1 to 4.0
```

Duration list: `0.1 0.2 0.3 0.5 0.8 5.0`.

The value `5.0` exceeds every instrument's maximum here. It sits in the list, it may be named in a table group, it may enter the ensemble — and it can never be realised. Under a hierarchy beginning with `Ins`, every attempt to use it will be skipped in favour of an admissible value, and if the group contains nothing else admissible, a comment appears.

This is a common and easily missed situation. A list value that no instrument can play is not an error, it is a silently unreachable item. If a duration you wrote never appears in any variant, check it against these ranges first.

Give the bass drum a realistic maximum of `0.5` instead, and the effect becomes musical rather than accidental: long durations now steer the piece away from the drum, and passages of sustained writing will naturally be scored for the instruments that can sustain.

## Constraints

Both values must be non-negative and the minimum must not exceed the maximum.

## Related

- [duration list](fields/duration-list)
- [duration relation](fields/duration-relation)
- [instruments](fields/instruments)
