# Rest Parameter

This is an attempt to summarize what is said in the manual 7.4.

# What is a rest?

A rest is an extra extension of time, after an entrydelay of an entry (note, chord) has finished.

When there is a rest, all events that come after the rest are delayed by the duration of the rest.

The whole collection of rests inserted will extend a structure duration beyond what was specified by the composer, it is additional time.

Rests do not overlap. A rest does therefore not have an "autonomous" duration like events do, it acts as a pure entrydelay.

# How is the length of a rest found

Using the LIST/TABLE/ENSEMBLE principles as any other parameter.
There is no dependency on the instrument.

# How are rests inserted?

RESTs are computed as the final parameter in the hierarchy, except if PERFORMANCE changes are to be inserted only after the rests.

Rests are inserted into the timestructure created by the entrydelays of all entries. 

Inserting a rest consists of the following steps:
1. Calculate a timespan as an ALEA picked value, the boundaries for this alea are given by the composer as a percentages of the structure duration.
2. Use this timespan to calculate the next provisional timepoint.
3. A search start to find the first timepoint that satisfies:
   a) The end of any entry (chord/single tone).
   b) After a "pseudo rests", before a general entry.
4. Use the selection principle on the formed ensemble to pick the rests length.
5. Calculate a new timespan and continue with step 2. Stop when there are no events left to insert rest into.

Some observations:
* general entries may be hard or impossible to find, it could even be no rests are inserted at all.
* As we cannot know the number of rests really, we cannot use TENDENCY mask.
* you will have some variance based on what random intervals are picked.



