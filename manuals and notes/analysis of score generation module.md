# Analysis of `score_generation.ml`

Scope: `pr26/lib/score_generation.ml` (3630 lines), read alongside `parameters.ml`
(the `proto`/`entry`/`note` types live in the former, but the value types they're
built from live in the latter), `selection.ml` (the six selection principles),
and `debug_log.ml` (the diagnostic side-channel). This is a diagnosis, not a
patch — it proposes a target architecture rather than a line-by-line rewrite of
what's there.

**Status: implemented (A–D below), verified against the existing test suite.**
`resolve_layer_autonomous`/`resolve_layer_chord_density` are now one shared
engine (`compile_hierarchy` → `hierarchy_plan` → `resolve_group`, plus the two
density-specific wrappers), the `sel_*`/`sel_*_debug` shadow API is gone (one
primitive per operation, `?ctx` always accepted), and `ChordDensity` under
`union = common-harmony` is now type-excluded
(`common_harmony_density`) rather than an `assert false`. `dune test` produces
byte-identical output before and after (a pre-existing, unrelated test-fixture
bug - an interval matrix listing `1..12` instead of `1..11` for `tr = 12` -
was fixed first so the suite could run clean as a baseline). Two scope notes,
so this doc stays an accurate record of what was actually built rather than
what was drafted:
- The "Per→Dyn→Reg fixed order, not hierarchy order" debug-trace fidelity
  bonus mentioned under section A was *not* implemented - it would have
  required folding Per/Dyn/Reg's before-pivot extraction into a single
  ordered walk of `hierarchy_plan`, and the benefit (debug-trace ordering
  only, never a value change) didn't justify the added risk in the same
  pass. Extraction order for those three, when several are simultaneously
  before `Ins`, is still fixed (Per, then Dyn, then Reg), same as before.
- `elem_role`'s `PerNote` constructor collided with `note_value`'s own
  `PerNote` and was renamed to `InstrumentLevel` while implementing -
  `plan_step`'s two constructors (`ComputeEntryValues`/
  `ComputeNotesForInstrument`) are unaffected, `elem_role` was always meant
  to be a private implementation detail underneath them.

## Verdict, up front

The domain model (`proto` → `entry` → `note`, the `hierarchy_elem` permutation,
`PerChord`/`PerNote` modes) is sound and should survive a rewrite intact. The
complexity is not in the model, it's in **how the three density modes each
re-implement the same hierarchy-walking machinery from scratch**, and in **how
debug logging was retrofitted as a parallel shadow API instead of a property of
one central interpreter**. Both are fixable without touching the model, and
both are large enough that fixing them would cut this file by something like a
third.

Two numbers worth sitting with: `resolve_layer_autonomous` (score_generation.ml:1354–1785,
~430 lines) and `resolve_layer_chord_density` (score_generation.ml:1798–2273,
~475 lines) are the same function. Not "similar" — line-for-line identical in
structure, with the same fifteen locally-defined helper closures in the same
order, differing only in (a) how the note-count target is computed and (b) a
handful of chord-specific lines for splitting percussion/pitched tones and
stamping harmony afterward. That is ~900 lines of hierarchy-walking logic that
should be one ~350-line generic engine plus two ~60-line strategies.

## What's good — keep this

- **`proto` / `entry` / `note`** (score_generation.ml:29–72, 326–358): a proto
  is a note under construction, one field per hierarchy parameter, each
  `option`-wrapped until that step of the hierarchy fills it in. This is the
  right shape for "resolve parameters in a composer-chosen order, and later
  steps may depend on earlier ones."
- **`note_value = Shared of 'a | PerNote of 'a list`** (score_generation.ml:313):
  a small, correctly-reused abstraction for "one value for the whole chord" vs.
  "one per note." Nothing to change here.
- **`selection.ml`** itself: six selection principles (Alea/Series/Ratio/Group/
  Tendency/Sequence), each with its own state type and `_draw`/`_draw_predicate`
  pair, unified behind `sel_state`/`sel_draw`/`sel_draw_pred_tagged`
  (score_generation.ml:91–232). This module is a good example of the kind of
  small, closed, well-factored abstraction the rest of the file needs more of.
- **`hierarchy_elem` as an explicit permutation**, validated once at
  formula-load time (`mk_hierarchy` in parameters.ml:92–99, plus the
  ordering-requires-X-first checks in structure_formula.ml around lines
  182–376). Keeping "is this hierarchy even legal" as a load-time, not
  run-time, question is the right call and should stay that way.
- **`apply_rest_insertions`** (score_generation.ml:2508–2527): generic over
  `'a` via `~shift_time`/`~mk_rest`, so REST's splice-in-a-rest logic is
  written once and reused by both the per-layer (`entry`) and common-harmony
  (`common_harmony_group`) pipelines. This is the pattern the density resolvers
  should have used and didn't.

## Root causes of complexity, ranked

### 1. The three density resolvers duplicate a ~450-line engine, near-verbatim

`resolve_layer_instrument_density` (score_generation.ml:1254–1275) is short and
fine — every entry is a singleton group, no sub-pick loop. The other two are
the problem:

- `resolve_layer_autonomous` (1354–1785): draws an autonomous density target,
  then fills sub-picks (instrument by instrument) until that target note-count
  is reached.
- `resolve_layer_chord_density` (1798–2273): draws a chord from the composer's
  table, splits it into a percussion-count and a pitched-count, then fills
  sub-picks for *each* count separately and concatenates.

Both define, in the same order, with the same names: `resolve_subpick`,
`instruments_of`, `max_duration_of`, `force_not_ok`, `mark_group_ok`,
`stamp_ok`, `fill_subpicks`, `keep_seed`, `draw_duration_before`,
`stamp_duration_after`, `finish_with_computed_entrydelay`, `fill_group`,
`fill_group_with_note_modes`. Chord density adds two more
(`fill_subpicks_split`, `split_chord`/`assign_harmony`) to handle the
percussion/pitched split and to stamp the drawn chord's tones back onto the
group afterward. Diff the two functions and the actual, load-bearing
difference is maybe 60 lines; everything else is copy-paste.

This means every future bug fix or behavior change to "how a chord's
entry-delay/duration interact" (there are four branches of that alone, see
`fill_group`'s `match (dur_relation, ent_before_dur)`) has to be made twice,
correctly, in sync, in two functions that don't call each other. That's not a
readability problem so much as a correctness-liability problem.

### 2. Every parameter's "before `Ins` or after `Ins`" logic is hand-written, per density mode

Because the hierarchy is a free permutation, whether e.g. `Reg` is drawn before
or after the instrument is picked changes which predicate applies and which
value gets shared across the chord. Today that's handled by computing four
booleans (`perf_before_ins`, `dyn_before_ins`, `reg_before_ins`,
`dur_before_ins`, score_generation.ml:1379–1382 and 1816–1819, identical in
both resolvers) and then writing an explicit `if extracted && before_ins then
... else ...` for each of performance, dynamics, register, and duration,
separately, inside `fill_group_with_note_modes` (1663–1765 and 2065–2204).
That's 4 parameters × 2 branches × 2 density modes = 16 near-identical
branches doing "decide now vs. decide after the loop and reconcile."

This is the "fractal" feeling the user described: the branching factor isn't
inherent to the domain (there are really only two cases — before or after —
per parameter), it's inherent to *writing out* the cross product by hand
instead of building one small interpreter that takes "where does this
parameter sit relative to `Ins`" as data.

### 3. Deep, same-shaped local closures make each function un-unit-testable

Both big resolvers are single top-level `let`s containing ~13–15 nested
`let`-bound closures, each capturing `hierarchy`, `perf_mode`, `dyn_mode`,
`dur_relation`, `reg_mode`, and the enclosing `states`/`proto` shape from the
outer scope. None of them can be called or tested independently; understanding
any one of them requires holding the whole enclosing function's variable set
in your head. This is a direct consequence of #1 — once the two engines are
unified into one, these closures become that engine's actual (testable,
nameable) internal functions instead of copies duplicated per call site.

### 4. Debug mode was bolted on as a parallel shadow API

This is worth its own section — see below.

### 5. Cross-cutting invariants are enforced far from where they're assumed

`resolve_harmony`'s `HarChord` branch is `assert false`
(score_generation.ml:1077–1082) because CHORD's harmony is never resolved
inside `resolve_step` — but the reason that's safe is a validation rule that
lives in `structure_formula.ml` (`ChordPrincipleCommonHarmonyMismatch`,
`HarmonyRequiresHarFirst`) enforced at formula-load time, in a different
module, hundreds of lines away. Similarly,
`calculate_layer_common_harmony_phase1` asserts `ChordDensity` is unreachable
(2736–2745) for the same reason. These asserts are correct today, but nothing
in `score_generation.ml` itself makes the illegal states unrepresentable —
the safety is a distributed invariant held together by comments pointing at
another file. That's brittle under refactoring: it is easy to add a new
density/union combination or move validation logic without noticing you've
invalidated an assert three files away.

## Debug mode: what happened, and what "from first principles" looks like

The suspicion is correct, and it's confirmed by the file's own comments.
`manuals and notes/debug_output.md` — the original request — explicitly asks
for "a clean implementation, that keeps the functions as readable as
possible." What actually landed is a **parallel API surface**: for every
selection primitive, there are now two functions, one plain and one
`_debug`-suffixed:

| plain | debug-instrumented |
|---|---|
| `sel_draw` | `sel_draw_debug` |
| `sel_sample` | `sel_sample_debug` |
| `sel_draw_pred_tagged` | `sel_draw_pred_tagged_debug` |
| `sel_sample_pred_tagged` | `sel_sample_pred_tagged_debug` |
| `sel_sample_pred` | `sel_sample_pred_debug` |

(score_generation.ml:271–301). The comment directly above them
(264–270) admits this explicitly: the `_debug` variants are kept separate from
the plain ones specifically so that "every one of \[the plain functions'\]
many existing call sites — most of them inside
`resolve_layer_autonomous`/`resolve_layer_chord_density`'s own per-chord
`fill_group` extraction, not yet wired for debug context — is provably
untouched." In other words: the plain/debug split exists because migrating
every call site to carry a context was judged too risky to do all at once, so
the codebase now permanently carries both versions, and *whether a given call
site's decisions are visible in the debug log at all depends on which of the
two nearly-identical functions someone happened to call there*. That's a
correctness trap for the debug feature itself, not just a style complaint.

On top of the doubled primitives, every function that might need to log
anything now takes a `~ctx : Debug_log.context` parameter purely to thread it
downward (`resolve_subpick`, `fill_subpicks`, `fill_group`,
`fill_group_with_note_modes`, `resolve_step`, `resolve_entry`...), and
`resolve_step` rebuilds a param-specific context by hand at the top of every
one of its six branches (`{ ctx with Debug_log.param = PIns }`,
score_generation.ml:1108, repeated for `PEnt`/`PDur`/`PPer`/`PDyn`/`PReg`).
None of this is wrong, exactly — `Debug_log`'s design (a mutable, opt-in,
thunked event buffer, `debug_log.ml:69–83`) is a perfectly reasonable choice
for an optional diagnostic side-channel, and is *not* the problem. The problem
is that instrumentation was added as a second code path alongside the real
one, instead of being a property of a single interpreter.

**From first principles**, if you were designing this today knowing you need
per-draw provenance, you'd want exactly **one** primitive that every hierarchy
step goes through to get a value out of a `sel_state` — call it `draw` — which
always has access to "what am I drawing, for which entry" (because it's the
one place that variable is ever in scope), and which unconditionally calls
into `Debug_log` internally (cheap when disabled: one `if !enabled` check,
which is already the pattern `Debug_log.emit` uses). There would be no second
`_debug`-suffixed family to keep in sync, and no call site could silently omit
instrumentation by calling the "wrong" one of a pair. Concretely: fold
`emit_sel_events`/`emit_restriction` *into* one drawing primitive that
`resolve_step` calls once per case, rather than exposing five separate
plain/debug pairs for callers to choose between. This becomes easy once the
hierarchy walk itself is unified (root cause #1/#2) — right now it's hard
mainly because there are two copies of the walk to migrate instead of one.

## Proposed architecture

The goal: one hierarchy-walking engine, parameterized by a small "density
strategy" value, with instrumentation as an intrinsic part of the one
draw primitive rather than a parallel API.

### A. Represent the hierarchy as one ordered plan, not a pile of booleans

The first draft of this section reached for a `compiled_hierarchy` record of
`_before_ins` booleans — but that wasn't derived from the domain, it was a
direct transcription of local `let`s the current code already has
(`perf_before_ins`, `dyn_before_ins`, `reg_before_ins`, `dur_before_ins`,
score_generation.ml:1379–1382 and 1816–1819). PR2's hierarchy is already an
ordered list, validated once as a permutation (`mk_hierarchy`,
parameters.ml:92–99) — flattening it into five named booleans throws that
order away and re-derives fragments of it per parameter, which is exactly the
"write out the cross product by hand" problem root cause #2 describes, just
committed one level higher up. The better version keeps the list as a list
and builds one small ordered plan from it, once:

```ocaml
(* One step of the plan, in the same relative order as the composer's own
   [hierarchy]. [ComputeEntryValues] names a hierarchy element decided once
   for the whole entry, at exactly the position its own entry occupies
   relative to every other element - entry-level or not. [ComputeNotesForInstrument]
   appears exactly once, standing in for [Ins]: it is the recipe for ONE
   instrument's own note(s) - which of the remaining, still per-note hierarchy
   elements it still has to walk (today's [subpick_hierarchy], unchanged in
   spirit) - not "build the whole chord" itself. Whatever loops this step
   once per instrument until the chord's target note count is reached is a
   separate, outer concern (today's [fill_subpicks], see section B) - the plan
   only ever describes what one instrument's own turn looks like. *)
type plan_step =
  | ComputeEntryValues of hierarchy_elem
  | ComputeNotesForInstrument of hierarchy

type hierarchy_plan = plan_step list

(* [Ent] is always entry-level - an entry delay is always a whole-chord fact,
   never per-note. [Har] is entry-level only under [ChordDensity] (the chord
   IS the harmony, drawn whole before any instrument is picked); everywhere
   else HARMONY resolves per-note, inside [ComputeNotesForInstrument]'s own
   sub-hierarchy. [Per]/[Dyn]/[Reg] are entry-level iff their own mode is
   [PerChord]. [Ins] is never entry-level - its position IS the pivot, which
   is exactly what "split whole-chord facts from per-note ones" means. [Dur]
   under [DurEqualsEntry] is a separate case - see below, this isn't quite
   total. *)
val compile_hierarchy :
  density:vertical_density -> perf_mode:note_mode -> dyn_mode:note_mode ->
  dur_relation:dur_relation -> reg_mode:note_mode ->
  hierarchy -> hierarchy_plan
```

The engine then folds over `hierarchy_plan` once: a `ComputeEntryValues` step
reached before the `ComputeNotesForInstrument` marker draws its value once and
seeds it into every instrument's own turn still to come; one reached after it
draws once, constrained to agree with every instrument already picked, and
stamps it onto every one of their notes. "Before or after `Ins`" stops being
state anyone tracks and becomes a fact read off a step's position in the list
— asked, not stored.

Two things worth being explicit about, both surfaced by taking the ordered
list seriously instead of summarizing it into booleans:

- **This doesn't quite cover `DurEqualsEntry`.** That relation isn't "make
  `Dur` entry-level at its hierarchy position" — under `ent_before_dur =
  false`, the *first* note built draws its own duration unconstrained, that
  value becomes the whole chord's entry delay, and only the *remaining* notes
  copy it in (`fill_group`'s `DurEqualsEntry, false` branch,
  score_generation.ml:1567–1589 and 1985–2014). That's a genuine
  cross-note sequential coupling, not an ordering fact — no amount of
  before/after cleverness makes it reduce to `ComputeEntryValues`. It needs its
  own third plan-step kind (e.g. `LinkedDurationEntry`) rather than being
  pretended away. Not every piece of this function is "just ordering," and the
  plan should say so rather than imply otherwise.
- **It fixes a small existing order-fidelity bug for free.** Today, when more
  than one of `Per`/`Dyn`/`Reg` are simultaneously extracted-and-before-`Ins`,
  the code draws them in a fixed textual order — `Per`, then `Dyn`, then `Reg`
  — regardless of which one the composer actually put first in the hierarchy
  (score_generation.ml:1664–1694 and 2064–2113). Harmless for the *value*
  (each has its own independent `sel_state`, so no predicate depends on draw
  order between them), but it means the debug trace's event order doesn't
  always match the declared hierarchy in that corner case. A plan built by
  walking `hierarchy` in true order fixes this as a side effect, not extra
  work.

This is still pure code motion relative to today's behavior (module the
order-fidelity fix above, which is a genuine, presumably-welcome behavior
change) — no new information is needed that `hierarchy`/`perf_mode`/
`dyn_mode`/`dur_relation`/`reg_mode` didn't already carry.

### B. One engine, parameterized by a density strategy

The actual difference between "autonomous" and "chord" density is: *how many
sub-picks are needed, and how are they grouped/tagged*. Everything after that
(entry-delay/duration interaction, performance/dynamic/register
before-or-after-`Ins` extraction, filling sub-picks, instrument-reuse
tracking) is identical. Model that difference as data:

```ocaml
(* One "segment" is a homogeneous run of sub-picks filled by one fill_subpicks
   loop - autonomous density has exactly one (the whole chord); chord density
   has up to two (percussion, pitched). *)
type segment_seed = {
  seg_target : int;
  seg_harmony_seed : row_value note_value option;  (* None for autonomous *)
}

module type Density_strategy = sig
  (* Called once per event/timepoint, before any sub-pick runs. Draws
     whatever the density mode needs from continuing_state (an autonomous
     target, or the next chord from the table) and returns the segments to
     fill plus updated state. *)
  val plan
    :  ctx:Debug_log.context
    -> continuing_state
    -> segment_seed list * continuing_state

  (* Called once the group's sub-picks are all resolved, in case the strategy
     needs to stamp something back on afterward (chord density's
     assign_harmony; autonomous density is a no-op here). *)
  val finish : proto list -> proto list
end
```

`resolve_layer_autonomous` becomes: draw one density target, `plan` returns a
single segment with that target and no harmony seed, `finish` is `Fun.id`.
`resolve_layer_chord_density` becomes: draw the next chord, `split_chord` it,
`plan` returns up to two segments (percussion/pitched) each seeded with the
right `cs_harmony_seed`, `finish` is today's `assign_harmony`. The
~350-line shared engine (today's `fill_subpicks`/`fill_group`/
`fill_group_with_note_modes`, unified once) takes a `Density_strategy` and
folds over the `hierarchy_plan` from (A) — one fold, replacing every
`if extracted && before_ins then ... else ...` pair with a single case match
on `ComputeEntryValues`-before-the-pivot vs. `ComputeEntryValues`-after-it vs.
`ComputeNotesForInstrument`.

Net effect: two ~500-line near-duplicates become one ~300–350-line engine plus
two ~40–60-line strategy modules. `resolve_layer_instrument_density` doesn't
need this machinery at all and can stay exactly as it is.

### C. Debug instrumentation as an intrinsic of the one draw primitive

Once (B) unifies the two engines' draw call sites into one place, collapse the
five plain/debug pairs into one primitive that always has `ctx` in scope
(because there's now only one hierarchy-walking loop, and `ctx` is naturally
available at its one call site per step) and always checks
`Debug_log.enabled` internally:

```ocaml
val draw
  :  ctx:Debug_log.context
  -> to_string:('a -> string)
  -> ?pred:('a -> bool)
  -> 'a sel_state
  -> 'a selection_result * 'a sel_state
```

No `_debug`-suffixed twin, no call site that can "forget" to opt in — every
call to `draw` is instrumented by construction, at zero marginal cost when
`Debug_log.enabled` is `false` (same short-circuit the current code already
relies on, just centralized to one function instead of five).

### D. Make the CHORD/common-harmony incompatibility a type, not an assert

`density : vertical_density` and `union : union_mode` are independent fields
today, and their one illegal combination (`ChordDensity` with
`NoUnionCommonHarmony`) is caught at formula-load time but re-asserted at
generation time three call sites away. If `structure_formula.ml` already
rejects this combination before a `cfg` value can exist, consider having it
hand `score_generation.ml` a value that makes the illegal pairing
unrepresentable instead of merely absent — e.g. a `density` type that only
offers `ChordDensity` inside the two union modes that support it (a GADT
indexed by union mode, or simply splitting `vertical_density` into "densities
legal under common-harmony" vs. "densities legal otherwise" and having
`generate_score_hierarchical`'s `NoUnionCommonHarmony` branch take the
narrower type). This is a smaller, optional change compared to A–C, but it
converts a distant, comment-documented invariant into something the compiler
enforces locally.

## Secondary observation: proto's parallel `_ok` fields

Not a priority, but worth naming: `proto` carries `duration`/`duration_ok`,
`register`/`register_ok`, `harmony`/`harmony_ok`/`harmony_matrix_ok` as
separate parallel `option` fields (parameters around score_generation.ml:326–358),
and `notes_of_proto` unwraps all of them with `match ... with Some tv -> tv |
None -> assert false` (2270–2279). A `'a note_value` that carried its own
"was this an Impossible fallback" flag as part of the type (rather than a
same-shaped sibling field the caller must remember to keep in sync) would
remove that whole class of `assert false` and make "this proto is fully
resolved" a checkable fact rather than a convention. Lower priority than A–D
above since it doesn't drive the duplication, but it would fall out naturally
if the engine in (B) is rewritten anyway.

## Suggested migration order

1. **`compile_hierarchy` extraction (A)** — build the `hierarchy_plan`
   (plus its `LinkedDurationEntry` special case) alongside the existing
   boolean-driven code first, verify it agrees with the old booleans on every
   test formula, *then* switch the old resolvers to read from it. Pure code
   motion except for the `Per`/`Dyn`/`Reg` order-fidelity fix noted above,
   which is a small, isolated, easy-to-call-out behavior change.
2. **Unify the two engines behind `Density_strategy` (B)** — the big one. Do
   it with the existing test suite (`test/test_pr26.ml`) as the safety net;
   this is a refactor where "produces byte-identical output for a fixed seed
   across representative formulas" is the right acceptance test before/after.
3. **Collapse the debug shadow API (C)** — do this *after* (B), not before:
   once there's one engine with one call site per hierarchy step, there's
   only one place to wire up instrumentation, and the current risk that
   motivated keeping plain/debug pairs separate (score_generation.ml:264–270)
   goes away on its own.
4. **Type-level illegal-state prevention (D)** — optional, lowest urgency,
   worth doing once (B) has already reshaped the density types anyway.
