# An index points past the end of its list

A cell in a table, or a value in a sequence or ratio, names a position that does not exist in the list it refers to.

## Why this matters

This is the single most common mistake in Project Two, and it comes from the one idea that organises the whole program: **tables never contain values, only indices into lists.**

The [list, table, ensemble chain](concepts/list-table-ensemble-order) works in three stages. The *list* is your stockpile for a parameter, the actual entry delays, dynamics or instruments you want available in the piece. The *table* arranges that stockpile into groups, and it does so by naming positions in the list, not the items themselves. The *ensemble* is then assembled from one or more of those groups and is what the [selection principle](concepts/selection-principles) finally draws from.

So a duration table cell containing `2` does not mean a duration of two seconds. It means *the third item in the duration list*, counting from zero. The design is deliberate: you write one long list once, and then form many different groupings and many different variants over it without ever restating the values. But it also means that indices and lists are coupled. Shorten a list, or delete an item from the middle, and every index above that point now refers to something else, or to nothing.

The same rule applies to a [sequence](concepts/selection-principles), whose values are list positions, and to [ratio](concepts/selection-principles) pairs, whose first slot is a list position. An ensemble sequence is one level up: its values are positions in the *table*, naming which groups to take.

## How to fix it

- Change the index to one that exists. Valid indices run from 0 to one less than the list's length; the message gives the exact upper bound.
- Add the missing item to the list, if the index was right and the list is what is incomplete.
- Check whether you recently deleted or reordered a list item. If so, other indices are likely to be wrong too even where they still point somewhere valid.
- If you were trying to write the value itself rather than its position, put the value in the list and reference its index here.
