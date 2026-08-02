# HARMONY: add the CHORD principle (EMR-3 §8.2, entries 15-18)

## Context

HARMONY currently implements two of its three EMR-3 principles: ROW (a flat
sequence of relative pitches, cumulatively transposed as a whole once
exhausted) and INTERVAL (a Markov chain over an interval-transition matrix).
CHORD, the third, has so far been explicitly out of scope (`harmony.md`,
`parameters.ml`'s own header comment) because it isn't just "a third way to
produce a stream of relative pitches" — per EMR-3 §8.2/§9.2, when CHORD is
selected HARMONY becomes the **main parameter**: it decides a whole chord
(tones *and* how many of them) per entry point, and vertical density is
simply whatever size that chord turns out to be — `density` can no longer be
autonomous or instrument-driven. This inverts today's resolution order,
where `Ins` always runs before `Har` and decides note-count first.

The user's own requirements, which take precedence over any ambiguous
manual wording (the manual's own OCR is inconsistent in a couple of
places), are:

1. Choosing CHORD principle automatically makes vertical density
   "chord principle" too — the two must never be able to disagree.
2. HARMONY must be the main/first parameter in the hierarchy when CHORD is
   used (parallel to the existing `InstrumentDensityRequiresInsFirst` rule
   for `Ins`).
3. Chord transposition works exactly like ROW's cumulative transposition
   (`row_stream` in `parameters.ml`: an offset accumulated from the
   *original* reference table, never compounded against the last-
   transposed pass), restricted to 4 modes instead of ROW's 5: none / alea
   / series / a composer-given explicit list of transposition intervals
   (distinct from ROW's "serial" mode, which reuses the row's own tones —
   CHORD's given-row mode is a separate list).
4. The order in which chords are drawn from the table uses the full
   general `selection_principle` (Alea/Series/Ratio/Group/Tendency/
   Sequence — `selection.ml:29-36`, already used by `density`'s own
   principle and by instrument/entrydelay/performance/dynamics/duration/
   register's `order` field), not a restricted 3-way selection.

Manual-confirmed, and load-bearing for the resolution design below: a
chord may mix percussion (0) and pitched tones, and percussion instruments
genuinely participate in "scoring" a chord's vertical density alongside
melody instruments (EMR-3 commentary, ~line 3120-3125: "percussion
instruments ... can participate in the 'scoring' of the vertical density
... A condition for this is however that the hierarchy has not already
established pitches or registers which automatically exclude all
percussion instruments"). So mixed-content chords are a real case the
resolution algorithm must handle correctly, not an edge case to special-case
away.

## Design decisions

- **Reuse `row_value` for chord tones** (`Tone of step | RowPercussion`) —
  it already encodes exactly "1..tr or percussion," so `resolve_pitch`,
  `transpose_value`, `row_value_is_percussion` etc. all work unchanged.
- **Chord transposition is pure, `parameters.ml`-level**, mirroring
  `row_stream`/`transposition_intervals` exactly, plus "chords starting
  with 0 are excluded from transposition" and in-chord zeros staying inert
  (`transpose_value`'s existing `RowPercussion -> RowPercussion` case
  already gives this for free).
- **Order-of-chords is `score_generation.ml`-level** (needs `sel_state`
  machinery) — one transposition-interval draw per `Array.length table`
  chord-draws, generalizing ROW's "one interval per completed pass through
  the row" to an order that isn't necessarily sequential (with a
  non-cyclic order like Alea this is an approximation — "N draws" rather
  than "every chord visited exactly once" — acceptable per the user's own
  "solve it the same way as ROW" framing).
- **A drawn chord's percussion and pitched tones are scored as two
  separate sub-groups.** An instrument's `pitchrange` is atomically either
  `PercussionPitchRange` or a real range — never both — so there's no
  per-note choice once a sub-pick's instrument is fixed; splitting lets the
  existing `fill_subpicks` trimming loop (used verbatim for `Autonomous`
  density today) be reused twice, once per homogeneous target, instead of
  inventing a new resolution primitive.
- **Mixed-chord register handling**: when `reg_mode = PerChord` and `Reg`
  precedes `Ins`, draw **two** shared registers for the group (one
  percussion-constrained, one pitched-constrained) instead of one — a
  single shared register can't be simultaneously compatible with both tone
  types, and the manual confirms mixed chords are real, so a single draw
  would spuriously flag one tone type IMPOSSIBLE on every mixed chord.
- **HARMONY's value is seeded into every sub-pick before its own fold
  runs** (`Shared RowPercussion` or `Shared (Tone ...)`, depending which of
  the two sub-groups it's in) purely so the existing percussion-agreement
  predicates (`ins_pred_from`, `reg_pred_from`) fire correctly — then
  overwritten with the real, sliced-from-the-drawn-chord per-note values
  once every sub-pick's `nr_of_notes` is final. `Har` never appears in
  `subpick_hierarchy` for CHORD — its value is always a whole-group fact,
  never drawn inside a sub-pick's own fold — so `resolve_step`'s `Har` case
  itself needs no changes; it simply isn't invoked under CHORD.

## Stage 1 — `pr26/lib/parameters.ml`: types

Near `row`/`mk_row` (~line 1082-1098):

```ocaml
type chord = Chord of row_value array
type chord_table = ChordTable of chord array
let mk_chord ~tr items = (* same shape as mk_row *)
let mk_chord_table ~tr (chords : int option list list) =
  match chords with [] -> Error EmptyChordTable | _ -> (* map mk_chord, sequence *)
```

Near `transposition`/`transposition_intervals`/`row_stream` (~line 1130-1194):

```ocaml
type chord_transposition =
  | ChordNoTransposition | ChordTransposeAlea | ChordTransposeSeries
  | ChordTransposeGiven of step list  (* TRANSP-CHORD option 3: an explicit
      given list, distinct from ROW's "serial" (reuse-the-row) mode *)

let mk_chord_transposition_given ~tr ints = (* map mk_step, sequence, wrap *)

let chord_transposition_intervals ~tr = function
  | ChordNoTransposition -> Seq.repeat 0
  | ChordTransposeAlea -> choose (List.init tr (fun i -> i + 1))
  | ChordTransposeSeries -> series_over_range tr
  | ChordTransposeGiven steps -> Seq.cycle (List.to_seq (List.map step_to_int steps))

let chord_starts_with_percussion (Chord arr) =
  Array.length arr > 0 && arr.(0) = RowPercussion

let transpose_chord ~tr k (Chord arr as c) =
  if chord_starts_with_percussion c then c
  else Chord (Array.map (transpose_value ~tr k) arr)
```

`harmony_principle` (~line 1309-1311) gains a third variant; `vertical_density`
(~line 769-771) uncomments its stub:

```ocaml
type harmony_principle =
  | HarmRow of { row : row; transposition : transposition }
  | HarmInterval of { matrix : interval_matrix; forbidden_tones : step list }
  | HarmChord of { table : chord_table; order : selection_principle;
                   transposition : chord_transposition }

type vertical_density = Autonomous of autonomous_density | InstrumentDensity | ChordDensity
```

New `problem` variants (follow the file's existing one-constructor /
`display_problem` / `problem_id` / `json_of_problem_data` convention,
~lines 36-65, 104-157, 307-340, 372-421):

- `EmptyChordTable` — "the CHORD table must contain at least one chord"
- `ChordTooLong of { len : int; tr : int }` — chord has more tones than `tr`
- `HarmonyRequiresHarFirst` — parallels `InstrumentDensityRequiresInsFirst`
- `ChordPrincipleDensityMismatch` — CHORD principle and chord-density must
  always agree, in both directions

Reuse the existing `KChord`/`KHarmony`/`KDensity`/`KHierarchy` keys; add one
new key, `KOrder`, for the chord-order field's own diagnostic location (so
it doesn't collide with `KPrinciple`, which already names the harmony
principle itself a few path segments up).

`chord_table_length_errors ~tr (ChordTable chords)` — a separate pass (like
`interval_matrix_dead_end_rows`) producing one diagnostic per over-long
chord, so each can carry its own `Index i` location; called from
`structure_formula.ml`, not baked into the smart constructor.

## Stage 2 — `pr26/lib/structure_formula.ml`: grammar and validation

Sexp shape:

```
(harmony
  (principle chord)
  (chords ((1 3 5) (2 p 7) (0 0 0)))
  (order series)
  (transposition none))          ; or (transposition (given (1 2 3)))
```

- `chords`: reuse `parse_row_item` per entry (already accepts an int or `"p"`).
- `order`: reuse `parse_principle` verbatim (no ratio-index override needed,
  same as `density`'s own principle field).
- `transposition`: 4 forms, the `given` one following the existing
  "leading keyword disambiguates a sub-form" idiom already used by
  `(matrix (rows ...))` vs `(matrix (chord ...))`.

Add a third `"chord"` branch to the harmony-principle match (~line 1013-1075),
inside `in_loc [Key KHarmony]`, alongside the existing `"row"`/`"interval"`
branches — same `in_loc`/`require_field` idioms throughout.

`parse_density` (~line 795-820) gains one bare-atom branch:
`[ Sexp.Atom "chord-density" ] -> Ok ChordDensity`.

In `mk_structure_formula` (~line 141-293), add:

- **Hierarchy-first check**, same shape as the existing `hierarchy_errors`
  (~line 151-163) but keyed on `ChordDensity` and `Har`, using
  `HarmonyRequiresHarFirst`.
- **Bidirectional CHORD ↔ ChordDensity consistency check** — `HarmChord`
  without `ChordDensity` (location `[Key KDensity]`) or `ChordDensity`
  without `HarmChord` (location `[Key KHarmony; Key KPrinciple]`), both
  `ChordPrincipleDensityMismatch`.
- **Guard off `per_note_ordering_errors`'s existing unconditional
  `needs_ins_first_always [Key KHarmony] Har`** (~line 271) — correct for
  ROW/INTERVAL (always per-note, `Ins` must precede `Har`), backwards for
  CHORD (`Har` must precede `Ins`). Only emit it for `HarmRow`/`HarmInterval`.
- **Chord table length check** — fold `chord_table_length_errors ~tr chords`
  into `all_diags` when `harmony = HarmChord {table; _}`.

## Stage 3 — `pr26/lib/score_generation.ml`: resolution algorithm

`har_state_t` gains a third variant:

```ocaml
type har_state_t =
  | HarRow of row_value Seq.t
  | HarInterval of { ... }
  | HarChord of {
      tr : int;
      table : chord array;           (* original reference table, never mutated *)
      order_state : chord sel_state;
      cumulative : int;               (* offset so far, mod tr, applied to
                                          the ORIGINAL table each draw *)
      drawn_since_pass : int;         (* draws since cumulative last advanced;
                                          a "pass" = Array.length table draws *)
      trans_intervals : int Seq.t;
    }
```

`initial_har_state` gets a `HarmChord` case initializing this (mirrors
`HarInterval`'s init); `start_new_variant` gets a `HarChord` case re-running
`tendency_init` when `order = Tendency ...`, exactly like the existing
`Autonomous`/instrument cases already do for their own `Tendency`-mode
selections.

`chord_next : har_state_t -> chord * har_state_t` (near `interval_next`,
~line 600-683): draws the next chord via `sel_draw order_state`
(unconditioned, same as `resolve_layer_autonomous`'s own density-target
draw), transposes it by `cumulative` via `transpose_chord`, and advances
`cumulative`/`drawn_since_pass`/`trans_intervals` once `drawn_since_pass`
reaches `Array.length table`.

`ins_pred_from` (~line 456-483) gains a `from_harmony` check mirroring
`reg_pred_from`'s existing `harmony_pred` (~line 557-568) — today `Ins`
doesn't condition on `Har` at all (fine, since `Har` always runs after
`Ins` for ROW/INTERVAL, so `proto.harmony` is always `None` when `Ins`
runs); this becomes live and necessary once `Har` can be seeded before
`Ins` runs, under CHORD.

`chord_seeds` (extends the existing `Autonomous`-only `cs_perf`/`cs_dyn`/
`cs_reg`/`cs_dur` seed record) gains `cs_harmony_seed : row_value note_value
option`, threaded into `resolve_subpick`'s `start` proto alongside the
others (one new field, no other change to `resolve_subpick`/`fill_subpicks`
— they're already generic over "a target count" and "a seeds record").

For CHORD, `subpick_hierarchy` unconditionally excludes `Har` (not
`PerChord`-conditional like `Per`/`Dyn`/`Reg`/`Dur` — harmony is always a
whole-group fact under CHORD, never drawn inside a sub-pick's own fold).

New top-level function, `resolve_layer_chord_density`, mirroring
`resolve_layer_autonomous`'s structure:

1. `split_chord (Chord arr)` → `(percussion_n, pitched_tones : row_value list)`.
2. A chord-aware variant of `fill_group`/`fill_group_with_note_modes` —
   call them `fill_group_chord`/`fill_group_chord_with_note_modes` — that
   generalizes each of `fill_group`'s 4 `(dur_relation, ent_before_dur)`
   branches to call `fill_subpicks` **twice** in sequence (once with
   `percussion_n` tones and `cs_harmony_seed = Some (Shared RowPercussion)`,
   once with `List.length pitched_tones` and `cs_harmony_seed = Some (Shared
   (Tone ...))`), threading `states`/`settled` between the two calls and
   concatenating their groups. Register's own `PerChord`-before-`Ins`
   extraction draws two shared registers instead of one (per the design
   decision above), one per sub-group, each constrained by
   `register_is_percussion` matching that sub-group's tone type.
   Performance/dynamics/duration extraction is unchanged (harmony-
   independent either way).
3. The per-entry-point draw loop: for each of `n_events`, `chord_next` draws
   the chord, `split_chord` splits it, `fill_group_chord_with_note_modes`
   scores it (ignoring `density` entirely, per the manual — CHORD's chord
   size *is* the vertical density), then `assign_harmony` does a post-hoc
   slice-and-stamp pass over the finished group: each percussion sub-pick's
   `nr_of_notes` worth of tones become `RowPercussion`; each pitched sub-
   pick consumes the next `nr_of_notes` tones off the shared, in-order
   `pitched_tones` list. `harmony_ok`/`harmony_matrix_ok` are always `true`
   for CHORD (no retry/fallback mechanism — the group composition is
   engineered to exactly match the drawn chord; a genuine mismatch can
   still surface as `pitch_ok = false` via `resolve_pitch`'s existing
   register-span-mismatch branch, unchanged).

Dispatch: `calculate_layer_hierarchical`'s density match (~line 1535-1544)
gains `| ChordDensity -> resolve_layer_chord_density ~n_events ~hierarchy ...`.

Exhaustiveness: `density_cell`/`density_header_comment` (~line 1941-1949)
each gain a `ChordDensity` arm (note count / `"# density: chord\n"`).

## Stage 4 — `pr26/test/test_pr26.ml`

Unit tests (pure `Parameters`-level):

- `transpose_chord`: `(1 3 5)` transposed by `k=2`, `tr=12` → `(3 5 7)`.
- `(0 3 5)` (starts with percussion) → unchanged regardless of `k`.
- `(1 0 5)` (percussion in the middle) transposed by `k=2` → `(3 0 7)` — the
  embedded zero stays inert while its siblings transpose.
- Cumulative-not-compounding: two passes through a small table under
  `ChordTransposeSeries`, assert pass 2's chords equal pass 1's chords each
  transposed by the same single interval (never double-transposed).
- `ChordTransposeGiven`: 3-chord table, `(given (2 5))` — pass 1
  untransposed, pass 2 by 2, pass 3 by `(2+5) mod tr`, cycling correctly.

End-to-end tests (build a full formula via `Parse.of_sexp`, run
`build_score`, following the existing `build_interval_formula` pattern):

- **Chord-size-drives-density**: 2-chord table (sizes 3 and 2),
  `hierarchy (Har Ins Reg Per Dyn Ent Dur)`, `density chord-density`,
  `order (sequence (0 1))` — assert every entry's note count alternates
  `3, 2, 3, 2, ...`, proving `density` is genuinely superseded.
- **Mixed percussion/pitched chord**: chord `(0 3)`, one percussion
  instrument and one pitched instrument available — assert every
  percussion-flagged note came from the percussion instrument, and the
  pitched note's relative pitch is `3` (as transposed).
- **Hierarchy validation**: `density chord-density` with a hierarchy not
  starting `Har` → `HarmonyRequiresHarFirst`.
- **Density/principle consistency**: `principle chord` + `density
  instrument-density` → error; `principle row` + `density chord-density` →
  error (other location).
- **Empty/oversized chord table**: `(chords ())` → `EmptyChordTable`; a
  chord longer than `tr` → `ChordTooLong`.

## Stage 5 — GUI (`gui/src/`)

- **`schema/types.ts`**: `HarmonyPrinciple` gains `"chord"`; a
  `ChordTransposition` type (`"none" | "alea" | "series" | {kind:"given";
  values:string[]}`, kept distinct from the existing `Transposition` since
  the option sets genuinely diverge); `chords: string[][]` (one
  `TokenListEditor` per chord — extend `ListEditors.tsx` with a small
  `ChordTableEditor` wrapper, add/remove-chord affordances); `chordOrder:
  Principle` (the existing type, reused wholesale). `Density` gains
  `{kind: "chord-density"}`.
- **`schema/sexp.ts`**: `emitHarmony` gains a `"chord"` branch; `emitDensity`
  gains the `chord-density` bare atom.
- **`schema/validate.ts`**: mirror the engine's four checks — the existing
  `instrument-density-requires-ins-first` block is the direct template for
  a new `harmony-requires-har-first` block; add `chord-principle-density-
  mismatch` comparing `harmonyPrinciple === "chord"` against `density.kind
  === "chord-density"`.
- **`screens/StructureScreen.tsx`**: add a `chord-density` option; when
  `harmonyPrinciple === "chord"`, gray out/hide the density selector
  (mirroring the existing `instrument-density` hint block) and auto-set
  `density = {kind:"chord-density"}` when switching into chord principle on
  the Harmony screen (auto-revert to a sane default when switching away) —
  so the two fields can never actually drift apart through the UI even
  though the model still represents them separately, matching the engine's
  own bidirectional-validation approach.
- **`screens/HarmonyScreen.tsx`**: a third `"chord"` branch alongside the
  existing `"row"`/`"interval"` ones — a chord-table editor, a
  `PrincipleEditor` for `chordOrder` (reused exactly as `StructureScreen
  .tsx` already does for density's own principle), and a 4-mode
  transposition `<select>` (reusing the existing `Transposition`-select
  markup, with a `given` option revealing a `TokenListEditor`).
- New help docs (`fields/harmony-chord*.md`, mirroring the existing
  `fields/harmony-*.md` set) and updates to `fields/harmony-principle.md`,
  `fields/density.md` to describe the new principle/density coupling.

## Verification

1. `dune build && dune test` after each of stages 1-4 (types, grammar,
   resolution, tests) — the file's own exhaustiveness-checking pattern
   (missing a `display_problem`/`problem_id`/`json_of_problem_data` clause,
   or a density-match arm) is a compile error, so this catches most
   integration mistakes immediately.
2. Run `main_sexp.exe` against a small hand-written CHORD formula and
   manually confirm the produced score's note counts per entry match the
   drawn chords' sizes, and that transposition passes look right.
3. `cd gui && npx tsc --noEmit && npm run check:help && npm run check:emitter`.
4. Manual click-through (`npm run app`/`npm run dev`): author a chord
   table, confirm the density selector locks to chord-density, confirm
   validation fires correctly for the mismatch/hierarchy cases, confirm a
   generated score's chord sizes match what was authored.
