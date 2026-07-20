# Variant

> One realisation of a structure formula. The formula describes a class of pieces; a variant is a single reading of it. Same formula plus same seed always gives the same variant.

When you press generate, the program reads your [structure formula](structure-formula) and produces a score. That score is a *variant*. It is not "the piece the formula makes" — it is one of the pieces the formula makes, and the formula's real content is the whole set of them.

This is the centre of Koenig's thinking, and it takes some getting used to. Most notation programs assume you are working towards a single fixed object. PROJECT TWO assumes you are working towards a *description*: a set of decisions about supply, grouping, order and constraint. Chance fills in everything you did not determine. What you actually composed is therefore visible only across several variants — the features that persist are yours, and the features that change from variant to variant were left open by you, whether you meant to leave them open or not.

The manual puts it plainly: since selection of parameter data in table and ensemble is usually aleatoric, the variant is not the only feasible interpretation of the structure formula. Other variants reveal the form potential of the structure formula step by step.

## Where the variation comes from

Every place chance enters is a place variants can diverge:

- which group is selected into the ensemble, at the ensemble stage of [list, table, ensemble, order](list-table-ensemble-order);
- which value the order principle draws next — [alea](alea) and [series](series) shuffles, [ratio](ratio) weightings, the repetition counts inside [group](group), the range sampled by [tendency](tendency);
- which instrument is picked to score a chord, and how the voices are shared out under [vertical density](vertical-density).

Principles differ sharply in how much they let vary. A [sequence](sequence) is fully determined and reads the same in every variant. `series` guarantees the *set* but not the succession. `alea` guarantees almost nothing. Choosing principles is largely choosing how much of the piece you are handing to chance.

## The seed

The [seed](fields/seed) makes chance reproducible. It is a whole number that sets the starting point of the random number generator, and it is the handle by which you move around the set of variants.

**Same formula + same seed = the same variant, exactly, every time.** Save it, close the program, regenerate a month later: note for note identical. A variant is therefore fully described by two things — the formula and the seed — and both are worth writing down for anything you want to keep.

**Same formula + a different seed = a different variant of the same structure.** Nothing about your compositional decisions has changed; you are simply hearing another reading of them.

The practical discipline that follows is worth stating as a rule: when you want to hear what an *edit* did, keep the seed and change one thing. When you want to hear what the *formula* is, keep the formula and step through seeds. Changing both at once teaches you nothing, because you cannot attribute the difference.

One caveat. The seed guarantees reproducibility only for an unchanged formula. Structural edits rearrange the sequence of random draws, so seed 3 before and after an edit does not give you "the same variant with one thing altered" — it gives you a different variant. The guarantee is exact, but it is exact about the pair.

## Variant duration

A variant has a stated length: [variant duration](fields/variant-duration), in seconds. It is a specification of scale rather than a boundary. The program divides it by the average entry delay of each layer's ensemble to estimate how many entry points that layer needs, then accumulates actual entry delays one after another until it has that many.

Because the delays are drawn by a selection principle rather than averaged, their sum need not land on the stated figure. A 30-second variant may come out at 28.4 or 31.7. This is expected and documented behaviour, not drift.

All [layers](layers) of a variant share the same variant duration and the same tempo, but each computes its own event count from its own entry-delay ensemble — which is exactly how a sparse strand and a rapid one come to occupy the same half minute.

## Example

Formula as written, [seed](fields/seed) 3, variant duration 30 s. You get a particular score.

Now step through seeds 1 to 10, touching nothing else. Ten variants of one structure. Listen for what they share.

- If they all sound alike, the formula is over-determined: [sequence](sequence) where you meant `series`, or table groups so narrow that only one outcome was ever possible. Chance has no room.
- If they have nothing in common, the formula is under-determined. You are hearing your material, not a piece.
- The useful state is in between — a recognisable family with genuinely different members.

## Related

- [structure formula](structure-formula)
- [seed](fields/seed)
- [variant duration](fields/variant-duration)
- [selection principles](selection-principles)
