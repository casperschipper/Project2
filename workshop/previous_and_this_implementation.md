# The many lives of Project 2

---
marp: true
---

---

## Command line versions:

* Koenig's original (~1966) on an Electrologica X1/X8.
![width:600px](img/Electrologica_X8.jpg)        <!-- fixed width -->

---

It had a terminal interface by answering a series of questions (over 60).
There were separate programs for each step, all reading and writing to disk (memory being limited) 
This made experimenting through various variants difficult, as you could not quickly switch a parameter and rerender.

---

* Atari Version (1990, Ramon Gonzalez-Arroyo & Koenig)

Based on the manual, the Atari version was very similar to the first version, with some minor differences.

---

## GUI versions

* Koenig's Visual Studio version with GUI (late 1990's? not released)
* ? supercollider implementation ?
* Luc's version (2010, Ocaml + JAVA GUI, in testing stage)
* Python (2020, Brito & Gunnarsson)

---

This last Python version was my starting point, as it was created with Koenigs involvement and fairly complete gui:
<https://www.researchcatalogue.net/view/1081939/1081944>

---

* First attempt was to finish the python version, 
but although the code was of high quality, it was difficult to get into.

---

## New Approach

* We split the program into an "engine" and a "gui" (following the attempt of 2010)
* We started with the engine first
* No series of questions, but an input defined as a "structure formula"

---

## Engine 

* Written in OCaml
* We started with only two parameters, instrument and entrydelay beginning to end.
* List - Table - Ensemble, selection principles

---

* We integrated Instrument and the Combination/Union mechanisms.
* The other parameters were added one-by-one.
* The "structure formula" remains the only link between the two

---

Challenges with making a GUI for PR2

* There is a lot of input required
* Many inputs in pr2 are "entangled"
* Generic words like "union", "combination" & "group" have specific usages within pr2, and when combined may have different consequences.

---

* In Pr2, values are often refered to by index (in table, ensemble)
* In this GUI, we show the index and the value it refers to

---

* The user should be informed but not overwhelmed
* Warnings should appear where they matter
* The shape of inputs should reflect the values that are "correct" for them, reduce "string obsession"
* "make impossible states impossible"

---

* Short feedback mechanisms for learning and experiment
* If a values causes problems inform the user immediately
* Generic terms are labeled with what they actually mean

---

## Our Tauri GUI

When the engine was done, we started to generate a GUI based on the structure formula (using our principles).

---

## Some choices we made along the way

* The GUI provides a lot of hints when the users enters values
* The documentation is closely integrated in the GUI.

---

* We intentionally left out the option to randomize the selection principles themselves (for now..)
* Optional elements in the GUI appear only when relevant
* Some parameter lists are derived from the instrument parameter,
(as it make no sense to have values that cannot be performed by any instrument)

---

* We added a arrow graph visualisation of interval method
* You can name instrument groups to track them better in different parameters

---

