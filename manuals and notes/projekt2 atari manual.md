
!{PR2-Atari-Manual-Pdf}


# Projekt 2 Atari Manual

Ramon Gonzalez-Arroyo & Gottfried Michael Koenig

---

## Definitions

References to other definitions are enclosed in inverted commas (").

__Absolute Pitch__

Pitch code for the entire pitch range, consisting of an octave digit (1 to 9) and a "relative pitch".

__Autonomous rest__

A rest subsequently inserted into the "rhythmic context" by means of the rest "parameter"; not to be confused with "pseudo rest".

__Call__

Another term for "program entry". Program entries are numbered with
"call numbers", which may be represented by the symbol #.

__Chord __

In general: all tones commencing simultaneously; each "entry point" is occupied by a chord. Specially: tones commencing simultaneously in accordance with a chord construction (see also "chord size" of an instrument, chord in terms of the harmonic "chord principle", "vertical density").

__Chord size__

Number of tones which an instrument can play simultaneously. Defined for each instrument between two limit values.
Chord principle
One of three harmonic principles. Several chords form a stockpile from which selections can be made according to a "selection principle".

__Combination__

A principle in PR2 which causes the indicated "parameter (s) " automatically to adopt
the sequence of group-indices in the instrument
parameter; the "groups" designated by these indices are put together to form an "ensemble". The parameters excluded from the combination obey their own "selection principles", with which however only one group can be indicated for the ensemble each time.

__Comment__

Indication in the score printout that certain parameter values violate the composer's rule, because suitable elements were not available in the
"ensemble". A "wrong element" is marked by a letter indicating the appropriate "parameter".

__Compatible parameters__

Parameters with elements which can be fitted together ad libitum. Care should be taken that the parameter "combinations" are compatible. Since elements for the score are selected according to an "ensemble", only the respective ensembles have to be compatible; but if group selection is aleatoric, the "lists" must be compatible too.

__Concealed rest__

"Autonomous rest" inserted into the "rhythmic context"; it is superposed by a sustained tone (or chord), because it replaces a
"sound entry" but
not a "general entry".

__Definite entry point__

Starting point of an "autonomous rest". The definite entry point is found after a "provisional entry point" has been fixed.
Definite rest delay
The time-lag between the end of an "autonomous rest"
and the "definite
entry point" of the next rest.

__Element__
Single value in "table" or "ensemble"; used as an index to identify a list "item".

__Ensemble__
An array (field of numbers) from which a "selection principle" chooses for the assembly of the score. The ensemble consists of one or more
"groups" taken from a "table" in accordance with a selection principle.

__Entry point__

Starting point of a tone, "chord" or "autonomous rest".
Entry range
Time range in which the "provisional entry point" of an "autonomous rest" is found aleatorically.
General entry
"Entry point"
of a tone or "chord" not superposed by a sustained tone or
chord.

__Group__

Elements of a "list" which are to be put jointly into an "ensemble". The composer assembles groups to form a "table".
Hierarchy
The order in which "parameters" are used to compose the score. If the parameters are interdependent the hierarchy can acquire major significance; it is established by the composer or aleatorically.

__Infinite row__

Sequence of pitches generated according to the "interval principle" as a consequence of an interval matrix.

__Instrumentation__

The allocation of instruments to "entry points", pitches, durations, intensities or modes of performance. In a stricter sense, instrumentation applies to already given tones in "chords", in which case the rules of "vertical density" must be obeyed.

__Interval principle__

One of three harmonic principles. An interval matrix, established by the composer or calculated by PR2, and containing the intervals allowed or forbidden to follow each given interval, results in an "infinite row" in which the tones are made to occupy the time-points in the score in chronological order.

__Item__

Single value (number or string) of a "parameter", stored in a "list".

__Layer__

Musical structure in which the values of each individual "parameter" are taken from a uniform stockpile ("ensemble") in chronological order in accordance with a particular "selection principle". A layer is either based on a single "group" in the ensemble or on the "union" of several groups. Without union several layers occur, and appear one after the other in the printout or playout of the score. For the printout of the parts, the layers are fitted together so that all the time values are in chronological order. Several layers always have the same "variant duration" and metronome tempo.

__List__

A stockpile of data provided by the composer for a particular
"parameter". List elements are assembled in the "table" to form
"groups".

__Main parameter__

The first "parameter" in the "hierarchy". The "selection principle" for the main parameter can do its work unencumbered, but creates conditions which in certain circumstances restrict the other parameters.

__Parameter__

This term is used in PR2 to indicate characteristics of the musical structure that can be applied to individual tones. These are: name and qualification of the instrument which is to play the tone, pitch, register, duration, time-lag before the next tone (entry delay), inserted rest, intensity, and mode of performance (or articulation).

__Inserted__

rests and performance mode are usually used in forming groups
of tones.

__Pitch grid system__
Division of the octave into single tones ("relative pitches"), tone

__Program entry__

A way of
supplying PR2 with data for a particular purpose. The
composer's
"structure formula" can at present be read via 65 program
entries.

__Provisional entry point__

A provisional entry point is established aleatorically within a given
"entry range" for
"autonomous rests". Starting from this provisional
entry point, the "definite entry point" is then sought.

__Pseudo chord__

Two or more tones commencing simultaneously due to entry delay 0.

__Pseudo rest__

Occurs when a tone's duration is shorter than its entry delay.

__Relative pitch

Pitch index within an octave, expressed in the form of a two-digit number between 1 and 24. Relative pitch 0 (0-pitch) means a percussion instrument.

__Rest duration__

The duration of an "autonomous rest", not to be confused with "pseudo rest".

__Rhythmic context__

All the time-data ("entry points" and ends of tones) in chronological order.

__Row principle__

One of three harmonic principles. A number of tones form a stockpile which can be transposed according to various principles.

__Selection__

The choice of elements in a given stockpile resulting in a new stockpile (or a final result) which is a permutation of the old one.

__Selection cycle__

Unique and complete application of a "selection principle", with a finite or unfinite number of selected elements. Finite selection cycles are repeated if more elements are required; infinite and finite selection cycles are stopped when the required number of results is obtained.

__Selection principle__

A rule governing the "selection" of elements in a given stockpile.

__Series__

Arrangement of the elements of a "parameter"
according to a particular
principle. The composer is free in his arrangement of the items and elements in "list" and "table". "Selection principles" are available for the formation of series in the "ensemble" and score. The result of a completed selection process is also occasionally known as a series, see also "selection cycle".

__Set of data__

All the composer's data used for calculating a variant.

__Sound entry__

"Entry point" for a tone or "chord" as opposed to the entry point for an
"autonomous rest".

__Structure formula__

The structural characteristics of the "parameters" and their items as expressed in the input data, rules for the "selection" of elements and for the "hierarchy" of the parameters, another designation for "set of data".

__Table__

Collective term for "groups". Represents a stockpile of groups among which selections can be made for the "ensemble" by means of a "selection principle".

__Transposition cycle__

"Selection cycle" of transposition intervals for the transposition of
"chords"
and rows which the composer ahs declared in the harmony
"parameter" for the "chord principle" or "row principle".

__Union__

The treatment of the "ensemble" as a single unit governed by the
"selection principle" for the score, regardless of the number of
"groups" comprising the ensemble. Only one "layer" results from union.

__Variant__

The result of a program run in which "ensemble" elements in the form of a "layer" (or a number of layers) structure the "variant duration".
Since "selection" of "parameter" data in "table" and "ensemble" is usually aleatoric, the variant is not the only feasible interpretation of the
"structure formula". Other variants can reveal the form potential of the structure formula step by step.

__Variant duration__

The duration in seconds, stated by the composer, of a "variant". Since the number of "entry points" is calculated from the variant's duration and the average entry delay, and the entry delays are determined by one of the "selection principles", the sum of entry delays does not necessarily correspond with the variant duration.

__Vertical density__

Number of tones commencing simultaneously at each time-point, regardless of the "chord size" of the instruments involved. An automatic check makes sure that the total number of superposed tones per "layer" does not exceed the number of tones in the "pitch grid".

__Wrong element__

An element in the "ensemble" which is used in violation of the rules inherent to the "structure formula" because no element can be found to satisfy the rules. Wrong elements are marked by a "comment" in the score.

---

## Data selection

DATA SELECTION

In order to understand PR2 and its practical applications, it is important to provide a clear picture of the kind of data to be used, and of their structure. For this purpose we distinguish items and their index numbers, lists, tables and ensembles. Items are either numbers or strings, the index indicating the position of an item (sometimes a pair of numbers) in a list, table or ensemble.

LIST

For every parameter except HARMONY, a list of items which the composer would like to employ in a piece is drawn up. Whether or not the items will actually occur in the piece depends on compositional conditions. A list item can only occur in a variant if its index is named in the table and if the group containing this index is selected for the ensemble.
We speak of a parameter list in the case of items for INSTRUMENT, REGISTER, ENTRY DELAY, DURATION, REST, DYNAMICS, MODE OF PERFORMANCE; there are tables for these lists. There are also lists without tables in #19 (tone row), #21 (interval matrix), #23 (forbidden tones), #49 (tempo), #51 variant duration).

TABLE

As well as the lists, a table must also be made for most of the parameters. The purpose of the table is to arrange the list items in groups or to make a selection among the items. The items themselves are never named in the table, only their corresponding list indices ("elements"). An index may be named more than once within a group. If no groups are to be formed, it is sufficient to name the list indices once as a single group.

ENSEMBLE

In working out a variant, one group per parameter is normally selected and registered in "ensemble". Under certain circumstances ("combination") several groups can make up an ensemble, in which case they are registered in the ensemble in the same order in which they are named according to the given selection principle.
The order of the items (represented by their list indices) in the ensemble is the final arrangement for the variant. The use of this arrangement for purposes of data selection for the score depends on the chosen selection principle.
Since list items can be named more than once in the table (whether in one group or distributed among several), repetitions of items can also occur in the ensemble, However, PR2 does not take this into account; the selection principle for the ensemble merely selects ensemble indices ("elements") regardless of the items they denote.
The final selection of the parameter items always obeys this LIST-TABLE-ENSEMBLE principle; assembly and permutation of the ensemble are governed by selection principles which the composer determines.
This arrangement was chosen 

1. to spare the composer from having to keep on feeding new lists. It is sufficient for all items involved in the composition to be combined once in long lists. One group per assembly in then formed and quoted for the respective group of variants;
2. in order to be able to produce other combinations automatically for various variants according to the same list. A selection principle is then responsible for giving each variant a different number and/or selection of table groups. In the following chapters, list and table indices (that is, the contents of tables and ensembles) are usually referred to as "elements". An element is accordingly a magnitude chosen by a selection program and only applied to a list as an index when necessary (for tests, or for the score printout) •

## THE SELECTION PROGRAMS

For the assembly of an ensemble from table-groups (how many groups? - which groups?) as well as for the formation of the score from ensemble data, PR2 features selection programs which the composer calls by stating their call numbers followed (if required) by additional data.

| Name | Behavior |
|---------|-----|
| ALEA | This program chooses elements from a given supply at random. |
| SERIES | In contrast to ALEA, there is a repetition check which prevents an element from being repeatedly chosen until all of them have been selected. As soon as the supply is exhausted, it is automatically regenerated. SERIES can be called by simply indicating its option number 2. |
| RATIO | This program chooses elements of a given supply at random, each element being given a ratio factor p. The factor p indicates how often the respective element may be selected before it disappears from the supply. As soon as the supply is exhausted, both it and the ratio factors are regenerated automatically. When calling RATIO, not only option number 3, but also ratio factors must be indicated for each list item: 3ii ...i
The first factor refers to the first item, the second one to the second item, etc. Ratio factor 0 is allowed; in this case the relevant item is blocked.
RATIO can only be applied to an ensemble. If a list item appears more than once in the ensemble, its ratio factor too must be mentioned a corresponding number of times.




