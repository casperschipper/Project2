# previous implementations

PR2 has existed in at least the following implementations:

## Command line versions:

* Koenig's original (~1966)
* Atari Version (1990, Ramon Gonzalez-Arroyo & Koenig)
* Supercollider (??? no information available)

These had a terminal interface by answering a series of questions (over 60). This made experimenting through various variants difficult, as you had no overview of your parameters.

The atari version is very close in functionality to the original, although the manual is much shorter.

## GUI

* Koenig's Visual Studio version with GUI (late 1990's? not released)
* Luc's version (Ocaml + JAVA GUI, in testing stage)
* Python (2020 , fairly complete gui, but no complete program)
In terms of graphical user interface the last was a very important references point.

## Approach

* We split the program into an "engine" and a "gui"
* We started with the engine first, as there already was a gui.

## Engine 

* I started with just implementing list, table ensemble and the selection principles.
* We then made a minimal implementation with only one parameter (entry delay), but worked it through beginning to end.
* We then added the other parameters one-by-one.
* The central object of the program is the "structure formala"

## GUI

We had an internal format (s-expr) that represented the complete structure formula. We then generated a GUI from the formula.
So all the GUI does, is generate a structure formula, this is then fed into the "engine".

## Some choices that make it different from the last prototype

* We left out the option to randomize the selection principles
* The GUI provides more hints when the users enters values
* The documentation is integrated in the GUI, so that you can quickly lookup what something is.
* Problems are explained where they occur
* We added a graph based visualisation of the interval method
* There is a debug mode that is not yet used