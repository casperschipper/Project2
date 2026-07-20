# A parameter appears twice in the hierarchy

The [hierarchy](concepts/hierarchy) lists the same parameter more than once.

## Why this matters

The hierarchy is the order in which Project Two resolves the parameters for each entry point. It is one of the composer's most consequential decisions, because parameters constrain one another: whichever comes first is the *main parameter*, whose [selection principle](concepts/selection-principles) works unencumbered, while every later parameter must work within the conditions already established. Deciding duration before entry delay makes a very different piece from deciding entry delay before duration, even with identical lists.

The hierarchy is therefore a permutation, an ordering of each parameter exactly once, not a program with repeated steps. A parameter that appeared twice would be resolved and then resolved again, and the second resolution would either discard the first, in which case the first was meaningless, or contradict decisions that later parameters have already been fitted around. There is no reading of a repeated entry that describes a coherent musical procedure.

## How to fix it

- Remove the duplicate, keeping the position that reflects the priority you want the parameter to have.
- Look at what is missing while you are here: a duplicate usually means another parameter was dropped, which will show up as an [incomplete hierarchy](incomplete-hierarchy).
- If you were trying to express that a parameter influences the result at two stages, that is not the hierarchy's job. Relationships between parameters are expressed by [combination](concepts/combination) and by the [duration relation](concepts/duration-relation).
