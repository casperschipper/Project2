# Alea

> Free random choice from the stockpile. Every element is equally likely every time, and repetitions are allowed.

`Alea` is the simplest of the [selection principles](concepts/selection-principles) and sits at the aleatoric end of the continuum. Each time a value is needed, one element of the active ensemble is picked at random; the ensemble is not modified, so the next draw has exactly the same odds. Nothing is remembered.

The musical consequence is worth stating plainly, because it surprises people: `alea` does **not** produce an even distribution over short spans. It produces clumps. Over twelve events drawn from three values you will typically see one value appear five times and another twice, and you will often see immediate repetitions. That is not a defect — it is what randomness sounds like. If you wanted evenness, you wanted [series](concepts/series). If you wanted controlled proportions, you wanted [ratio](concepts/ratio).

Use `alea` when you want a parameter to be genuinely neutral: a background dimension that should not assert a shape of its own, so that some *other* parameter's structure can be heard clearly. It is also the honest choice when you simply do not know yet, and want to hear the raw content of a group before deciding how to order it.

## Example

Ensemble: `0.2 0.4 0.8` (entry delays).

Twelve draws with `alea` might give

```
0.4  0.4  0.8  0.2  0.4  0.4  0.2  0.8  0.8  0.4  0.2  0.4
```

Note the doubled `0.4` at the start, the run of `0.8`, and that `0.2` appears only three times in twelve. Another run with a different [seed](fields/seed) will look quite different — and equally lopsided.

## As an ensemble principle

In the *ensemble* slot, `alea` picks the active table group at random for each layer, with repetition allowed. Two layers may therefore end up on the same group, which under [union](fields/union) simply doubles that group's weight in the merged pool. If you want the layers to be guaranteed distinct, use `series` for the ensemble slot instead.

One caution from the manual: when the group selection is aleatoric, *all* your lists must be mutually compatible, not merely the ensembles you had in mind. Any group may turn up against any other, so a dynamic group that no instrument group can play will eventually surface as a wrong element and a [comment](fields/comment).

## Related

- [series](concepts/series) — the repetition-checked counterpart
- [ratio](concepts/ratio) — weighted randomness
- [selection principles](concepts/selection-principles)
