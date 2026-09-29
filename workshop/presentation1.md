---
marp: true
theme: default
paginate: true
footer: "PR2 Workshop · historical context + basic model"
style: |
  section {
    font-family: Inter, Avenir Next, Helvetica, Arial, sans-serif;
    background: #fbfaf7;
    color: #161616;
  }
  h1 { font-size: 1.85em; letter-spacing: -0.02em; }
  h2 { font-size: 1.45em; letter-spacing: -0.015em; }
  h3 { font-size: 1.05em; }
  p, li { font-size: 0.78em; line-height: 1.38; }
  blockquote {
    border-left: 0.18em solid #111;
    padding-left: 0.8em;
    font-size: 1.25em;
    line-height: 1.25;
  }
  .small { font-size: 0.62em; color: #555; }
  .tag { font-size: 0.62em; letter-spacing: .07em; text-transform: uppercase; color: #666; }
  .diagram { font-family: Menlo, Consolas, monospace; font-size: 0.78em; line-height: 1.4; }
  .columns { display: grid; grid-template-columns: 1fr 1fr; gap: 2.2rem; }
  .three { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1.3rem; }
---

<!-- _class: lead -->

# A Cross-Platform Reimplementation of Gottfried Michael Koenig’s *Project 2*

### Casper Schipper and Luc Döbereiner

<span class="small">Workshop · historical context, basic model, and first practical orientation</span>

<!-- Sources: Koenig, Project 2, Electronic Music Reports 3 (1970); Berg 2009; Laske 1981; Koenig 1987; Koenig, Layers and Variants; Bjarni Gunnarsson, Research Catalogue, 2020. -->

---

# Workshop Overview

1. Historical context and artistic motivations
2. What PR2 is: From structure to variants
3. How PR2 thinks: parameters, lists, tables, ensembles, selection principles
4. What we reimplemented, and what changed in practice
5. Hands-on work with complete structure formulas

---

<!-- _class: lead -->

# 1 · Historical context and basic model

<span class="tag">What is PR2?</span>

---

# PR2

*Project 2* is a computer-assisted composition program for calculating **musical structure variants** from composer-defined rules and data.

<div class="diagram">
composer defines rules, data, and parameter order<br>
program calculates one or more variants<br>
composer evaluates the musical consequences
</div>

---

# Not a composing machine

> “the computer does not ‘compose’”

The computer performs a mechanical task that would otherwise be slow, repetitive, or practically impossible for the composer.

<span class="small">Koenig, *Project 2*, Electronic Music Reports 3, Introduction.</span>

---

# From Project 1 to Project 2

<div class="columns">
<div>

### Project 1
- Developed 1964–66
- More closed system
- Some structural relations calculated by the program
- Fewer parameters
- One main layer

</div>
<div>

### Project 2
- Developed 1966–68
- More open system
- Composer defines the structure formula
- More parameters and dependencies
- Multiple layers / polyphonic thinking

</div>
</div>

---

# Artistic motivation: rules as a way of discovering material

> “given the rules, find the music”

PR2 reverses a familiar analytical relation. Instead of deriving rules from a finished piece, the composer formulates rules and explores the music they make possible.

---

# Artistic motivation: form emerges through material

> “form was what it was all about”

For Koenig, “material” is not only sound. It also includes procedures, tables, rules, and ways of combining parameters.

---

# Artistic motivation: variants, not one definitive realization

PR2 makes it possible to define a structural problem and generate related solutions.

<div class="diagram">
structure formula<br>
├─ variant 1<br>
├─ variant 2<br>
└─ variant 3 ...
</div>

The compositional object is not only a score, but a field of related possibilities.

---

# Basic vocabulary

<div class="three">
<div>

### Rules
Selection, permutation, dependency, hierarchy, grouping.

</div>
<div>

### Data / elements
Durations, dynamics, instruments, pitch materials, articulations.

</div>
<div>

### Parameters
Musical dimensions through which events are specified.

</div>
</div>

A **structure formula** is the specific combination of rules and elements for several parameters.

---

# Important PR2 parameters

- Instrument
- Harmony / pitch
- Register
- Entry delay
- Duration
- Rest
- Dynamics
- Mode of performance / articulation

The parameters are not independent: once one parameter has been composed, later parameters adapt to it according to the composer’s hierarchy.

---

# List, Table, Ensemble

<div class="diagram">
LIST      = available values for one parameter
             ↓
TABLE     = composer-made groupings of list values
             ↓
ENSEMBLE  = selected groups available to the selection principle
             ↓
SCORE     = chosen values placed into the structure
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

main parameter conditions later parameters

The hierarchy is therefore formal: it decides which parameter gets priority, and which parameters must adapt.

<span class="small">Example dependency pairs include pitch/register and entry delay/duration.</span>

---

# Layers: from serial sequence to polyphonic structure

Koenig’s layer concept moves from one-dimensional sequence toward simultaneous structures.

- PR1: one main layer, later interpretable polyphonically
- PR2: multiple layers as part of the model
- Layers can share duration and tempo while carrying different parameter materials

---

<!-- _class: lead -->

# Our starting point

Bjarni Gunnarsson’s 2020 Research Catalogue project described a modern implementation effort based on recent specifications by Koenig and Koenig’s input.

We take over from Bjarni and Darien’s work as a practical and conceptual starting point for a new cross-platform reimplementation.

---

