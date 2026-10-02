---
marp: true
theme: default
paginate: true
style: |
  /* One type scale: body = 1em; everything else is a step from it. */
  section {
    font-family: Inter, Avenir Next, Helvetica, Arial, sans-serif;
    font-size: 28px;
    line-height: 1.4;
    padding: 64px 80px;
    background: #fbfaf7;
    color: #161616;
  }
  h1 { font-size: 1.6em; letter-spacing: -0.02em; margin-bottom: .6em; }
  h2 { font-size: 1.3em; letter-spacing: -0.015em; }
  h3 { font-size: 1em; margin-bottom: .3em; }
  p, li { font-size: 1em; line-height: 1.4; }
  blockquote {
    border-left: 0.16em solid #111;
    padding-left: 0.8em;
    font-size: 1.15em;
    line-height: 1.35;
    color: #161616;
    margin: .6em 0 .8em;
  }
  .small, .quote-source { font-size: .65em; color: #666; }
  .quote-source { margin-top: 1.2em; }
  .tag { font-size: .65em; letter-spacing: .07em; text-transform: uppercase; color: #666; }
  .columns { display: grid; grid-template-columns: 1fr 1fr; gap: 2rem; align-items: start; }
  .three { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1.5rem; align-items: stretch; }
  .flow { display: flex; align-items: center; gap: .75rem; margin: 1.2rem 0; }
  .node {
    border: 1.8px solid #161616;
    border-radius: 14px;
    background: #fffefa;
    padding: .6rem .85rem;
    font-size: .8em;
    line-height: 1.3;
    box-shadow: 0 2px 0 rgba(0,0,0,.12);
  }
  .node strong { display: block; font-size: 1em; margin-bottom: .15rem; }
  .arrow { font-size: 1em; line-height: 1; color: #222; }
  .card { border-top: 2px solid #111; padding-top: .55rem; }
  .card p { font-size: .9em; }
---

<!-- _class: lead -->

# A Cross-Platform Reimplementation of Gottfried Michael Koenig’s *Project 2*

### Casper Schipper and Luc Döbereiner

<span class="small">Workshop</span>

---

# Workshop Overview

- Historical context and artistic motivations
- What PR2 is: From structure to variants
- How PR2 thinks: parameters, lists, tables, ensembles, selection principles
- What we reimplemented, decisions and design
- Hands-on work with complete structure formulas
- Future of the project

---

# PR2

*Project 2* is a computer-assisted composition program for calculating **musical structure variants** from composer-defined rules and data.

<div class="flow">
  <div class="node"><strong>Composer</strong>defines rules, data, and parameter order</div>
  <div class="arrow">→</div>
  <div class="node"><strong>Program</strong>calculates one or more variants</div>
  <div class="arrow">→</div>
  <div class="node"><strong>Composer</strong>evaluates the musical consequences</div>
</div>

---


# Not a composing machine

> “the computer does not ‘compose’; it merely carries out the orders which it is given.”

The computer performs a mechanical task that would otherwise be slow, repetitive, or practically impossible for the composer.

<div class="quote-source">Koenig, Project 2, Electronic Music Reports 3, Introduction.</div>

---

# The aim: a general compositional tool

> “There ought … to be programmes which any composer can use just as he uses manuscript paper, a piano or a tape-recorder.”

PR2 is not only a historical program; it is a proposal for a compositional medium.

<div class="quote-source">Koenig, Project 2, Preface.</div>

---


# PR2 shifts the composer’s task

> “the user of PR-2 is a designer who defines both the data base and the procedures brought to bear on it.”

PR2 is less about asking the computer to invent a piece, and more about designing a situation in which musical consequences can appear.

<div class="quote-source">Otto Laske, “Composition Theory in Koenig’s Project One and Project Two,” 1981.</div>

---

# Artistic motivation: rules as discovery

> “given the rules, find the music”

PR2 reverses a familiar analytical relation. Instead of deriving rules from a finished piece, the composer formulates rules and explores the music they make possible.

<div class="quote-source">Koenig, quoted in Berg, “Composing Sound Structures with Rules,” 2009.</div>

---

# Artistic motivation: material is already formal

> “Material was held to be the substratum of every artistic endeavour; artistic endeavour seemed impossible without a precise definition of the material.”

For Koenig, “material” is not only sound. It also includes procedures, tables, rules, and ways of combining parameters.

<div class="quote-source">Koenig, “Genesis of Form in Technically Conditioned Environments,” 1987.</div>

---

# Artistic motivation: form as process

> “I experience form as a process … every bar on paper, every sound on tape changes its formal function …”

This is close to the attitude PR2 encourages: form is not simply imposed from above, but discovered through operations on material.

<div class="quote-source">Koenig, “Genesis of Form in Technically Conditioned Environments,” 1987.</div>

---

# Variants

PR2 makes it possible to define a structural problem and generate related solutions.

<div class="flow">
  <div class="node"><strong>Structure formula</strong>rules + elements + parameter hierarchy</div>
  <div class="arrow">→</div>
  <div class="node"><strong>Variant 1</strong>one realization</div>
  <div class="node"><strong>Variant 2</strong>another realization</div>
  <div class="node"><strong>Variant 3</strong>another realization</div>
</div>

The compositional object is not only a score, but a field of related possibilities.

---

# Related material variants

> “This enables the composer … to design the work on the basis of related material variants.”

A variant group is not just a set of alternatives. It is a way of composing with a defined space of possibilities.

<div class="quote-source">Koenig, “Layers and Variants,” 1997.</div>

---

# Basic vocabulary

<div class="three">
<div class="card">

### Rules
Selection, permutation, dependency, hierarchy, grouping.

</div>
<div class="card">

### Data / elements
Durations, dynamics, instruments, pitch materials, articulations.

</div>
<div class="card">

### Parameters
Musical dimensions through which events are specified.

</div>
</div>

A **structure formula** is the specific combination of rules and elements for several parameters.

---

# Important PR2 parameters

<div class="columns">
<div>

- Instrument
- Harmony / pitch
- Register
- Entry delay

</div>
<div>

- Duration
- Rest
- Dynamics
- Mode of performance / articulation

</div>
</div>

The parameters are not independent: once one parameter has been composed, later parameters adapt to it according to the composer’s hierarchy.

---

# List, Table, Ensemble

<div class="flow">
  <div class="node"><strong>LIST</strong>available values for one parameter</div>
  <div class="arrow">→</div>
  <div class="node"><strong>TABLE</strong>composer-made groupings of list values</div>
  <div class="arrow">→</div>
  <div class="node"><strong>ENSEMBLE</strong>selected groups available to a selection principle</div>
  <div class="arrow">→</div>
  <div class="node"><strong>SCORE</strong>chosen values placed into the structure</div>
</div>

---

# Selection principles

PR2 offers several ways to choose values or groups:

<div class="columns">
<div>

- **ALEA** — random choice
- **SERIES** — random choice with repetition check
- **RATIO** — weighted choice

</div>
<div>

- **GROUP** — repeated values / group formation
- **SEQUENCE** — user-defined order
- **TENDENCY** — changing boundaries / mask

</div>
</div>

---

# Hierarchy: why order matters

PR2 calculates parameters one after another.

<div class="flow">
  <div class="node"><strong>Main parameter</strong>gets priority</div>
  <div class="arrow">→</div>
  <div class="node"><strong>Later parameters</strong>must adapt</div>
  <div class="arrow">→</div>
  <div class="node"><strong>Formal result</strong>depends on the order</div>
</div>

<span class="small">Example dependency pairs include pitch/register and entry delay/duration.</span>

---

# Layers: from serial sequence to polyphonic structure

Koenig’s layer concept moves from one-dimensional sequence toward simultaneous structures.

- PR1: one main layer, later interpretable polyphonically
- PR2: multiple layers as part of the model
- Layers can share duration and tempo while carrying different parameter materials

---

<!-- _class: lead -->

# Implementing Project 2

---

# The original

Koenig’s original (1966–1968*) was developed in Algol 60 on an Electrologica X8.

![w:640px](img/Electrologica_X8.jpg)

<div class="quote-source">* Koenig, “Composition Processes,” 1978.</div>

---

# Working with the original

- A terminal interface: the user answered a series of questions (over 60)
- Separate programs for each step, all reading and writing to disk (memory was limited)
- Experimenting with variants was difficult: you could not quickly change a parameter and re-render

---

# Atari version

- 1990, Ramon Gonzalez-Arroyo and Koenig
- Based on the manual, very similar to the first version, with some minor differences

---

# GUI versions

- Koenig’s Visual Studio version with GUI (late 1990s?, not released)
- SuperCollider implementation (?)
- Luc’s version (2010, OCaml + Java GUI, in testing stage)
- Python (2020, Brito and Gunnarsson)

---

<!-- _class: lead -->

# Our starting point

Bjarni Gunnarsson’s 2020 Research Catalogue project described a modern implementation effort based on recent specifications by Koenig and Koenig’s input.

We take over from Bjarni and Darien’s work as a practical and conceptual starting point for a new cross-platform reimplementation.

<https://www.researchcatalogue.net/view/1081939/1081944>

---

# First attempt

- Our first attempt was to finish the Python version
- It was hard to find a starting point, ironically because it was already so far developed

---

# New approach

- Read the manual(s)
- Split the program into an “engine” and a “GUI” (following the attempt of 2010)
- Start with the engine first
- No series of questions: the input is defined as a “structure formula”

---

# Engine

- Written in OCaml
- Started with only two parameters, instrument and entry delay, from beginning to end
- List – Table – Ensemble, selection principles

---

# Challenges with making a GUI for PR2

- A lot of input is required
- Many inputs in PR2 are “entangled”
- Generic words like “union”, “combination”, “entry” and “group” have specific usages within PR2, and when combined may have different meanings

---

# Avoiding incorrect input

There are so many ways to make an “incorrect” input that it could be very difficult to get any output at all.

- The user should be informed
- Warnings should appear at the location of the problem
- The shape of inputs needs to be appropriate (numbers, elements, octave, pitch class)
- Avoid meaningless repetitions of earlier inputs
- Short feedback loops for learning and experimenting
- Use the manuals’ jargon, but explain what it means

---

# Our Tauri GUI

When the engine was done, we started to generate a GUI based on the structure formula, following these principles.

---

![](img/Project2GithubQR.png) 
https://github.com/casperschipper/Project2

---

<!-- # Some choices we made along the way

- The GUI provides a lot of hints when the user enters values
- The documentation is closely integrated in the GUI
- We intentionally left out the option to randomize the selection principles themselves (for now)
- Optional elements in the GUI appear only when relevant
- Some parameter lists are derived from the instrument parameter (it makes no sense to have values that cannot be performed by any instrument)
- We added an arrow graph visualisation of the interval method
- You can name instrument groups to track them better in different parameters

--- -->

# What makes PR2 different?

- The order of values is highly automated, but the values themselves are provided by the composer as a list and never modified; the program permutes orders and layers
- This matters: in harmony, for example, certain pitches can be forbidden from ever occurring anywhere

---

# Tendency masks

- Tendency masks in PR2 do not act on continuous ranges
- They are moving boundaries over the formed ensemble, hence the name “mask”

---

# An instrumental program

PR2 thinks of music as instruments playing notes. It has some extra possibilities as well:

- Extreme densities
- Non-standard (≠ 12) octave divisions
- Any performance techniques defined by the composer
- Percussion (specifically non-pitched) instruments

---

# Selection, revisited

- **RATIO** is not simply a weighted choice: it is better understood as a series with repetitions in its seed row
- The weights of **RATIO** always refer to the full list, not the ensemble
- Serial thinking is very present, but PR2 also has generators that are the exact opposite: forced repetition, series with repeated elements, or hand-composed sequences

---

# Combining parameters

When parameters are combined, the composer can construct vertical relationships.

- For example: a group of durations and dynamics that may only occur together in one voice and not in the others

---

# When instrument is first

<https://sonology.org/wp-content/uploads/2019/10/Doebereiner-Model-and-Material.pdf>
