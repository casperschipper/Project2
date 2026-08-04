# Rest Parameter

This is an attempt to summarize what is said in the manual 7.4.

# What is a rest?

A rest is an extra extension of time, that comes after the entrydelay of an entry. 

When there is a rest, all events that come after the rest are delayed by the duration of the rest.

The whole collection of rests inserted will thus extend a variant or layers duration beyond what was specified by the composer, it is additional time.

Rests do not overlap with other rests. A rest does therefore not have an "autonomous" duration like events do, it acts as a pure entrydelay.

# How is the length of a rest found

Using the LIST/TABLE/ENSEMBLE principles as any other parameter.
There is no dependency on the instrument.

# How are rests inserted?

RESTs are computed as the final parameter in the hierarchy, except if PERFORMANCE changes are to be inserted only after the rests.

Rests are inserted into the timestructure created by accumulating the entrydelays.

Inserting a rest consists of the following steps:
1. Calculate a timespan as an ALEA picked value, the boundaries for this alea are given by the composer as a percentages of the structure duration.
2. Use this timespan to calculate the next provisional timepoint.
3. From this point, start a search to find the first timepoint that satisfies:
   a) "Before Next Sound Entry": after the end of the entrydelay of the current playing entry (chord/single tone).
   b) "Before Next General Entry": After a "pseudo rest", before a general entry.
4. Use the selection principle on the formed ensemble to pick the rests length.
5. Calculate a new timespan and continue with step 2. Stop when there are no events left to insert rest into.

Some observations:
* general entries may be hard or impossible to find, it could even be no rests are inserted at all.
* As we cannot know the number of rests really, we cannot use TENDENCY mask.
* you will have some variance based on what random intervals are picked.



