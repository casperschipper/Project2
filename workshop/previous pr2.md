# The many lives of Project 2

---

## Command line versions:

* Koenig's original (~1966)
* Atari Version (1990, Ramon Gonzalez-Arroyo & Koenig)
* Supercollider (??? no information available)

---

These all shared a terminal interface by answering a series of questions (over 60). This made experimenting through various variants difficult, as you had no overview of your parameters.

The atari version is very close in functionality to the original, although the manual is much shorter.

---

## GUI versions

* Koenig's Visual Studio version with GUI (late 1990's? not released)
* Luc's version (2010, Ocaml + JAVA GUI, in testing stage)
* Python (2020 , fairly complete gui, but no complete program)
In terms of graphical user interface the last was a very important references point.

---

## Approach

* We split the program into an "engine" and a "gui" (following 2010)
* We started with the engine first, as there already was a gui (from 2020)
* The link between the two is the "structure formula"

---

## Engine 

* Written in OCaml
* We started with only one parameter, beginning to end.
* List - Table - Ensemble, selection principles, score generation
* We then added the other parameters one-by-one.
* The central state of this program is the "structure formala"

---

## Our Tauri GUI

The Engine had an internal format (s-expr) that represented a complete structure formula. We then started to generate a GUI based on the formula. Almost all communication happens through the formula, although there is some settings and state of the GUI as well.

---

## Some choices we made along the way

* We left out the option to randomize the selection principles themselves
* The GUI provides more hints when the users enters values
* The documentation is fully integrated in the GUI.

---

* Optional elements appear only when relevant
* Some parameter lists are derived from the instrument parameter,
(it make no sense to have values that cannot be performed at all)

---

* We added visualisation of interval method
* You can name instrument groups to track them better in different parameters

---

citation from:
https://sonology.org/wp-content/uploads/2019/10/Doebereiner-Model-and-Material.pdf

One of the most central ideas in PR2 is that of a hierarchy of parameters. A position
in the hierarchy is assigned to each parameter, which determines the order of execution
and precedence of parameters in case of conflicts among produced values. The hierarchy,
however, is only meaningful where parameters depend on each other. The instrument
parameter is both the most constraining and the most constrained parameter, depending
on its position in the hierarchy, but all parameters – with the exception of the rest
parameter – are linked to the instrument parameter. In my understanding, one of the
most important decision the user has make is whether the instrument will be the last
(or one of the last) or the first parameter. When the instrument parameter is last in
the hierarchy (and provided there are a variety of differently defined instruments and
possible parameter values given), the program has to find an instrument that matches all
the constraints set by the chosen values. In other words, the program is orchestrating a
given structure. If it is the case that the instrument is the first element in the hierarchy,
the choice of instrument precedes and conditions all subsequent selections. In that case,
the orchestration is given and the rest of the structure has to follow its possibilities/