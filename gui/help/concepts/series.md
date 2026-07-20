# Series

> Random choice with a repetition check: no element returns until every element has been used. Then the supply is regenerated and the process starts again.

`Series` is the workhorse of PROJECT TWO and the natural first choice for most parameters. It guarantees that everything you put into a group will actually be heard, and heard about equally often, while leaving the succession itself free. In Koenig's terms it is a permutation principle: each complete pass through the supply is one *selection cycle*, and cycles follow one another for as long as values are needed.

Musically this is the difference between a vocabulary and a habit. Under [alea](concepts/alea) a group of six durations may effectively behave like a group of three, because chance keeps returning to the same ones. Under `series` all six are structurally present, and the listener has a real chance of perceiving the *set* rather than just its loudest members. It is the principle that makes your table groups audible as characters.

Note what `series` does **not** guarantee: an element can still appear twice in immediate succession, when it happens to end one cycle and begin the next. The check operates within a cycle, not across the boundary. If you need to avoid that, use [sequence](concepts/sequence); if you want repetition on purpose, use [group](concepts/group).

## Example

Ensemble: `p mf f ff` (four dynamics). Sixteen draws:

```
cycle 1:  mf  ff  p   f
cycle 2:  f   p   ff  mf
cycle 3:  ff  mf  f   p
cycle 4:  p   f   mf  ff
```

Each dynamic occurs exactly four times in sixteen events. Notice the `f | f` across the cycle 1–2 boundary: legal, and not uncommon.

If the same group had been read with `alea`, sixteen draws might have given `ff` six times and `p` twice.

## Repeated indices

Because a table group may name the same list index more than once, `series` also gives you a simple way to weight material without leaving the principle. A group written `0 0 1 2` contains four elements, two of which denote the same value, so each cycle produces that value twice and the others once — an exact 2:1:1 proportion, cycle by cycle. This is often steadier and easier to reason about than [ratio](concepts/ratio), which shuffles its weighted supply. See [indices](concepts/indices).

## As an ensemble principle

In the *ensemble* slot, `series` chooses table groups without repetition until all groups have been used. With three groups in the table and two layers per variant, successive variants will systematically work their way through the available combinations rather than settling on a favourite. This is exactly the automation the [list, table, ensemble, order](concepts/list-table-ensemble-order) chain was designed for: one table, many variants, guaranteed coverage.

## Under hierarchy

When a parameter lower in the [hierarchy](concepts/hierarchy) is constrained, `series` offers the first element of its current cycle that satisfies the constraint, and removes only that one. The cycle therefore stays intact and the guarantee survives — with the caveat that if nothing in the remaining cycle is admissible, a wrong element is emitted and marked with a [comment](fields/comment).
