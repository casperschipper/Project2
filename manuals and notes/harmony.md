# Thoughts on harmony:

Three principles:

* Chord 
* Row
* Interval

First observation: in the manual, values need to be provided for all. We will not require this.

Chord is complicated, as it includes vertical density.
HARMONY has three principles in PR-2: CHORD, ROW and INTERVAL
(EMR-3 §8.2). This module implements only ROW, the simplest of the
three: unlike CHORD it never becomes "main parameter" and never
determines vertical density (that stays independent, see EMR-3 p.115
/ fig 9-5), and unlike INTERVAL it has no constraint matrix to solve -
it is just a given sequence of steps that gets transposed as a whole
each time it has been used up. 

Original PR-2 marks a percussion event by "abusing" a pitch value: relative
pitch 0, and register (0,0). We replace that with a real sum
type: a tone is either a pitch (a register plus a step within it) or a
percussion event, which carries no pitch information at all.

HARMONY (and so ROW) only ever decides the step. The octave placement
(register) is a separate hierarchy parameter whose order relative to
HARMONY the composer chooses freely (EMR-3 p.74-77, fig 7-6), so no
register is known yet at this stage. ROW therefore produces this
lighter value; combine it with a register, once one is chosen
elsewhere, via [attach_register].

