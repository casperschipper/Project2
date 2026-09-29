open Parameters
open Structure_formula
open Selection
open Tools
open Observable_selection

(* Warnings about conditions that could not be met *)
type note_diagnostics = {
  (* [false] if could not keep duration requirement *)
  duration_ok : bool;
  (* [false] if percussion / pitched between register and harmony principles could not be fulfilled *)
  pitch_ok : bool;
  (* [false] iff HARMONY's INTERVAL principle hit its "restrictions too
     strict" fallback for this note (see [proto.harmony_matrix_ok]) - always
     [true] under ROW. Kept separate from [pitch_ok] since it's a distinct
     failure mode with its own comment. *)
  harmony_matrix_ok : bool;
  (* [true] iff this note's instrument had already been picked earlier within
     the same autonomous-density chord *and* no other otherwise-compatible
     instrument was still unused - i.e. there genuinely weren't enough
     distinct instruments to "score" the chord without reusing one (EMR-3
     8.16). Picking an unused instrument is always preferred first (see
     [resolve_step]'s [Ins] case), so this never fires just because the
     ensemble happened to land on the same instrument again while others
     were still free. *)
  instrument_repeated : bool;
}

(* Notes are the fundamental lowest level type of events in PR2 *)
type note = {
  time : float;
  instrument : instr;
  performance : Performance.t;
  dynamic : Dynamic.t;
  duration : duration;
  pitch : pitch;
  diagnostics : note_diagnostics;
  (* Stable identifier (variant/layer/entry/note-within-chord) - see
     [Debug_log.note_id]. Assigned once, in [entry_of_group], from the same
     loop index used to build [notes]; never recomputed afterwards. *)
  id : Debug_log.note_id;
}

(* Entry is one timepoint:
  In Pr2, you can have multiple notes starting at one entry point / time slot in the score.
  Analogous to a "chord". For many parameters you can state if it should be selected on the chord level (all notes at the timepoint have the same value), or are selected for each note within the chord.
  These parameters are therefor optional, if not specified on entry they are dealt with on a note level.
*)
type entry = {
  time : float;
  entrydelay : float;
  notes : note list;
  instrument : instr option;
  performance : Performance.t option;
  dynamic : Dynamic.t option;
  duration : duration option;
  pitch : pitch option;
  (* see [note_diagnostics.instrument_repeated] - true if any note in this
     entry is. *)
  instrument_repeated : bool;
  (* [true] iff this is a REST (EMR-3 7.4), spliced in by
     [insert_rests_entries]/[insert_rests_common_harmony_layer] - never a
     genuinely resolved entry (those always have [notes <> []]). Every
     other field mirrors an empty/silent event: [notes = []],
     [duration = Some (Duration <rest length>)], everything else [None]. *)
  is_rest : bool;
  (* Stable identifier (variant/layer/entry) - see [Debug_log.entry_id]. A
     resolved entry's [id] is permanent from the moment [entry_of_group]
     builds it; a REST's [id] identifies which resolved entry it was placed
     immediately before (see [Debug_log.entry_seq]) - neither ever gets
     renumbered by later rest-splicing. *)
  id : Debug_log.entry_id;
}

(* Extract all elements from any ensemble as a flat array. Each element
   keeps the LIST index it was resolved from (not just its value)
  this is important for RATIO, as the weights always refer to the original LIST index.
   *)
let ensemble_values_union ensemble =
  match ensemble with
  | Ensemble groups ->
      groups |> List.map elements_from_indexed_ensemble |> Array.concat
  | SingleGroup elm -> elm |> elements_from_indexed_ensemble

let ensemble_values_no_union ensemble =
  match ensemble with
  | Ensemble groups -> groups |> List.map elements_from_indexed_ensemble
  | SingleGroup g -> [ g |> elements_from_indexed_ensemble ]


let calculate_number_of_events variant_duration entry_delay_principle
    entry_delay_ensemble =
  let avg_ed = expected_value entry_delay_principle entry_delay_ensemble in
  int_of_float (floor (variant_duration /. avg_ed))

(* ---- Hierarchical entry resolution ---- *)

(* A parameter that can be chord-wide or per-note (MOD-DUR/MOD-DYN/MOD-PERF)
   ends up either as one [Shared] value copied to every note, or as one
   independently-resolved value [PerNote] per note. *)
type 'a note_value = Shared of 'a | PerNote of 'a list

let value_at note_values i =
  match note_values with Shared v -> v | PerNote vs -> List.nth vs i

(* 
  A "proto" is a note being build up parameter by parameter.
  The "hierarchy" in PR2 refers to the order of computation. 
  Later parameters may be limited in their choice by already computed ones.
  The filtering for this always happens on the ensemble level. 
  If no element can be picked, PR2 will pick a "wrong" one and insert a warning.
  If instrument density is used, the density is only known when the instrument has been picked @luc?
  *)
type proto = {
  entrydelay : entrydelay option;
  instrument : instrument option;
  nr_of_notes : int option;
  performance : Performance.t note_value option;
  dynamic : Dynamic.t note_value option;
  duration : duration note_value option;
  (* [false] iff no candidate duration actually satisfied the duration/
     entry-delay relation and this note's value is an [Impossible] fallback. *)
  duration_ok : bool note_value option;
  register : register note_value option;
  (* [false] iff no candidate register actually satisfied [reg_pred_from]
     (a "wrong register... provided with a comment", EMR-3 §7.1) and this
     note's value is an [Impossible] fallback. *)
  register_ok : bool note_value option;
  harmony : row_value note_value option;
  (* [false] iff the row-stream search in [resolve_step]'s [Har] arm hit its
     try cap without finding a value agreeing with [Reg] - see there. Always
     [true] for a percussion-forced tone. *)
  harmony_ok : bool note_value option;
  (* INTERVAL-only: [false] iff [interval_next] hit its "INTERVAL
     RESTRICTIONS TOO STRICT" fallback (the given interval's matrix row had
     no allowed successor at all, or none whose tone wasn't forbidden) - a
     distinct failure mode from [harmony_ok], kept separate so it gets its
     own comment (see [note_problems]). Always [true] for ROW and for a
     percussion-forced tone. *)
  harmony_matrix_ok : bool note_value option;
  (* [true] iff, within the current autonomous-density chord, this proto's
     instrument had already been picked by an earlier entry in the same
     chord - set by [resolve_layer_autonomous]'s [fill_group] once the whole
     group is known; always [false] outside that density mode. *)
  instrument_repeated : bool;
}

let empty_proto =
  {
    entrydelay = None;
    instrument = None;
    nr_of_notes = None;
    performance = None;
    dynamic = None;
    instrument_repeated = false;
    duration = None;
    duration_ok = None;
    register = None;
    register_ok = None;
    harmony = None;
    harmony_ok = None;
    harmony_matrix_ok = None;
  }

(* States threaded through the hierarchy fold — one per parameter hierarchy
   controls. [instr_arr] is kept here so a step can constrain itself to
   values achievable by at least one instrument in this group, even before
   [Ins] has run. *)
(* Running phase for HARMONY's INTERVAL principle (EMR-3 8.2, entries
   21-24) - the second "row principle" alongside ROW's [row_value Seq.t].
   The chain runs on *intervals*, not tones, so what's needed between draws
   is the last tone *and* the last interval used to reach it - except right
   at the start, where neither exists yet ([NotStarted]) or only the very
   first (ALEA-chosen) tone does ([HaveTone], about to bootstrap the first
   interval "where at least one 0 occurs in its line"). See
   [interval_next]. *)
type interval_phase =
  | NotStarted
  | HaveTone of step
  | HaveTransition of step * int

(* Which of HARMONY's two "row principles" is active, and its own running
   state - a variant instead of two separate [continuing_state] fields since
   only one is ever meaningful for a given formula (chosen once, at
   formula-load time, never mixed). [tr]/[matrix]/[forbidden] are constant
   for the whole run, kept alongside the evolving [phase]/[seen_since_reset]
   so [resolve_step]'s [Har] case doesn't need extra parameters threaded in
   just for this - mirrors how ROW's own [tr]/[transposition] are already
   "baked into" its [Seq.t] rather than passed around separately. *)
type har_state_t =
  | HarRow of row_value Seq.t
  | HarInterval of {
      tr : int;
      matrix : interval_matrix;
      forbidden : step list;
      phase : interval_phase;
      seen_since_reset : Pitch_set.t;
    }
  | HarChord of {
      tr : int;
      table : chord array;
          (* the ORIGINAL, untransposed reference table -
           the manual's "reference tones" - never mutated *)
      order_state : chord sel_state;
          (* SEQ-CHORD: the general selection
           principle over table entries *)
      cumulative : int;
          (* transposition offset accumulated so far, mod tr -
           applied to the ORIGINAL table each draw, exactly like
           [row_stream]'s own [cumulative] *)
      drawn_since_pass : int;
          (* draws since [cumulative] last advanced; a
           "pass" = [Array.length table] draws, regardless of which chords
           they actually were *)
      trans_intervals : int Seq.t;
          (* remaining stream of per-pass
           transposition intervals *)
    }

(* Threaded across every layer (and, once built, every variant - see
   [build_score]) rather than rebuilt fresh each time: EMR-3 6.2/8.2 are
   explicit that a selection cycle "passes over the layers and can only
   make a fresh start with a new variant group". *)
type continuing_state = {
  instr_state : instrument sel_state;
  ed_state : entrydelay sel_state;
  perf_state : Performance.t sel_state;
  dyn_state : Dynamic.t sel_state;
  dur_state : duration sel_state;
  reg_state : register sel_state;
  (* Not a [sel_state]: HARMONY's two "row principles" are each their own
     bespoke, order-preserving stream (EMR-3 8.2), never an Alea/Series/
     Tendency draw - see [row_stream] and [interval_next]. *)
  har_state : har_state_t;
  (* REST (EMR-3 7.4): unlike every field above, never threaded through
     [advance_all_windows] or [resolve_layer_groups]'s fold - REST never
     enters the hierarchy at all (see [rest_mode]), so it is only ever
     read/written directly by [insert_rests_entries]/
     [insert_rests_common_harmony_layer]. Each of those calls [sel_draw]
     once per rest placed, which already advances a [Tendency] window per
     draw (appropriate for a one-shot-per-rest value) - the same reason
     [har_state] needs no [advance_all_windows] entry either. *)
  rest_state : duration sel_state;
  rest_last_arr : duration element array;
  instr_arr : instrument array;
  (* The array each state above was most recently built against. Compared
     against the next layer's own array by [continue_or_restart]: EMR-3
     p.130-132 has an uncombined parameter draw a fresh group every layer,
     so this is the common case, not a rare one - a state only keeps
     drawing from the pool it was actually built for. *)
  instr_last_arr : instrument element array;
  ed_last_arr : entrydelay element array;
  perf_last_arr : Performance.t element array;
  dyn_last_arr : Dynamic.t element array;
  dur_last_arr : duration element array;
  reg_last_arr : register element array;
}

let advance_all_windows states =
  {
    states with
    instr_state = sel_advance_window states.instr_state;
    ed_state = sel_advance_window states.ed_state;
    perf_state = sel_advance_window states.perf_state;
    dyn_state = sel_advance_window states.dyn_state;
    dur_state = sel_advance_window states.dur_state;
    reg_state = sel_advance_window states.reg_state;
  }

(* Continues an existing cycle if this layer's array is the very one the
   state was already built against - an uncombined parameter's freshly-drawn
   group happens to repeat, a combined parameter mirrors instrument's own
   per-variant-fixed batch, or instrument's own group is unchanged. Starts a
   fresh cycle otherwise (EMR-3 6.2: "a new group is used for each layer, the
   table-groups can be organized correspondingly" - the composer's concern,
   not this function's). *)
let continue_or_restart ~principle ~n ~last_arr ~arr state =
  if last_arr = arr then state else sel_init principle n arr

(* The starting point before the very first layer of a run: every array
   below is empty, which no real (already-validated, non-empty) parameter
   array can ever equal - so [continue_or_restart] always takes the fresh
   branch for layer 0, exactly as if there were no prior state at all. *)
let initial_har_state ~tr (harmony : harmony_principle) : har_state_t =
  match harmony with
  | HarmRow { row; transposition } -> HarRow (row_stream ~tr ~transposition row)
  | HarmInterval { matrix; forbidden_tones } ->
      HarInterval
        {
          tr;
          matrix;
          forbidden = forbidden_tones;
          phase = NotStarted;
          seen_since_reset = Pitch_set.empty;
        }
  | HarmChord { table = ChordTable chords; order; transposition } ->
      HarChord
        {
          tr;
          table = chords;
          order_state = sel_init order 1 (elements_of_array chords);
          cumulative = 0;
          drawn_since_pass = 0;
          trans_intervals = chord_transposition_intervals ~tr transposition;
        }

let initial_continuing_state ~tr (harmony : harmony_principle) :
    continuing_state =
  {
    instr_state = SAlea (alea_init [||]);
    ed_state = SAlea (alea_init [||]);
    perf_state = SAlea (alea_init [||]);
    dyn_state = SAlea (alea_init [||]);
    dur_state = SAlea (alea_init [||]);
    reg_state = SAlea (alea_init [||]);
    har_state = initial_har_state ~tr harmony;
    rest_state = SAlea (alea_init [||]);
    rest_last_arr = [||];
    instr_arr = [||];
    instr_last_arr = [||];
    ed_last_arr = [||];
    perf_last_arr = [||];
    dyn_last_arr = [||];
    dur_last_arr = [||];
    reg_last_arr = [||];
  }

(* Resolve one chord-wide-or-per-note parameter at its hierarchy position:
   [PerChord] draws once and shares it across every note; [PerNote] draws
   independently once per note. [n_notes] must already be known (an
   instrument, and hence chordsize, is required to precede any per-note
   parameter - enforced at formula-load time by
   [Structure_formula.mk_structure_formula]'s per-note-ordering check). *)
(* Same as [resolve_note_param], but also reports, per note, whether its
   value actually satisfied [pred] (vs. being an [Impossible] fallback) - so
   a caller that cares (duration, re: the entry-delay relation) can flag it,
   while one that doesn't (performance, dynamics) just ignores the flags. *)
let resolve_note_param_tagged ?ctx ?to_string mode n_notes pred state =
  match mode with
  | PerChord ->
      let v, state' = sel_sample_pred_tagged ?ctx ?to_string pred state in
      let ok = result_ok v in
      (Shared (get_value v), Shared ok, state')
  | PerNote ->
      let n = Option.value n_notes ~default:1 in
      let vs, oks, state' =
        List.init n (fun _ -> ())
        |> List.fold_left
             (fun (acc, oks_acc, st) () ->
               let v, st' =
                 sel_sample_pred_tagged ?ctx ?to_string pred st
               in
               let ok = result_ok v in
               (get_value v :: acc, ok :: oks_acc, st'))
             ([], [], state)
      in
      (PerNote (List.rev vs), PerNote (List.rev oks), state')

let resolve_note_param ?ctx ?to_string mode n_notes pred state =
  let values, _oks, state' =
    resolve_note_param_tagged ?ctx ?to_string mode n_notes pred state
  in
  (values, state')

let duration_range_ok (AllowedDurations { min; max }) (Duration d) =
  min <= d && d <= max

(* [Ins]'s predicate: an instrument must be compatible with whatever of
   performance/dynamic/duration has already been resolved for this entry (if
   any) - the same "constrain on what's already chosen" idea used
   symmetrically by [Per]/[Dyn]/[Dur] below when [Ins] hasn't run yet. For a
   per-note value, *every* note's value must fit the instrument (EMR-3
   7.3: "if the durations in the chord are equal, instruments can only be
   selected which can play the selected duration; if not the same, this
   question is posed for each duration and instrument"). *)
let row_value_is_percussion = function RowPercussion -> true | Tone _ -> false

(* Under ROW/INTERVAL, [Ins] always precedes [Har], so [proto.harmony] is
   always [None] here and this is a dead branch - it only becomes live for
   CHORD, where harmony is seeded into every sub-pick's [start] proto
   *before* its own fold (and hence [Ins]) runs (see
   [resolve_layer_chord_density]). Mirrors [reg_pred_from]'s existing
   [harmony_pred] exactly. *)
(* Every [*_pred_from] below returns [(pred, restricted_by)]: the predicate
   itself, plus the short list of reasons it's non-trivial - derived from the
   very same checks the predicate applies, rather than re-inspecting [proto]
   independently, so the two can't drift apart (see
   "manuals and notes/debug_output.md"'s "restricted by instrument x" /
   "restricted by duration"). [restricted_by] is cheap to always compute (a
   handful of list operations, negligible next to the array/list work these
   functions already do unconditionally) so callers that don't care (when
   [Debug_log.enabled] is [false]) can simply ignore it. *)
let ins_pred_from proto =
  let from_harmony (Instrument { pitchrange; _ }) =
    let is_percussion = pitchrange = PercussionPitchRange in
    match proto.harmony with
    | None -> true
    | Some (Shared h) -> is_percussion = row_value_is_percussion h
    | Some (PerNote hs) ->
        List.for_all (fun h -> is_percussion = row_value_is_percussion h) hs
  in
  let from_perf (Instrument { performance = modes; _ }) =
    match proto.performance with
    | None -> true
    | Some (Shared p) -> Performance_modes.mem p modes
    | Some (PerNote ps) ->
        List.for_all (fun p -> Performance_modes.mem p modes) ps
  in
  let from_dyn (Instrument { dynamics = modes; _ }) =
    match proto.dynamic with
    | None -> true
    | Some (Shared d) -> Dynamic_modes.mem d modes
    | Some (PerNote ds) -> List.for_all (fun d -> Dynamic_modes.mem d modes) ds
  in
  let from_dur (Instrument { durations; _ }) =
    match proto.duration with
    | None -> true
    | Some (Shared d) -> duration_range_ok durations d
    | Some (PerNote ds) -> List.for_all (duration_range_ok durations) ds
  in
  let from_reg (Instrument { pitchrange; _ }) =
    match proto.register with
    | None -> true
    | Some (Shared r) -> register_compatible_with_pitch_range pitchrange r
    | Some (PerNote rs) ->
        List.for_all (register_compatible_with_pitch_range pitchrange) rs
  in
  let checks =
    [
      ("performance", proto.performance <> None, from_perf);
      ("dynamic", proto.dynamic <> None, from_dyn);
      ("duration", proto.duration <> None, from_dur);
      ("register", proto.register <> None, from_reg);
      ("harmony", proto.harmony <> None, from_harmony);
    ]
  in
  let pred i = List.for_all (fun (_, _, f) -> f i) checks in
  let restricted_by =
    List.filter_map
      (fun (n, active, _) -> if active then Some n else None)
      checks
  in
  (pred, restricted_by)

(* [Per]/[Dyn]'s predicate: restrict to modes the (already- or not-yet-known)
   instrument can play, exactly mirroring [Ins]'s own conditioning above. *)
let mode_pred_from_instrument ~instr_arr ~mem proto_instrument instr_modes =
  let pred =
    match proto_instrument with
    | Some i -> fun v -> mem v (instr_modes i)
    | None -> fun v -> Array.exists (fun i -> mem v (instr_modes i)) instr_arr
  in
  let restricted_by =
    if proto_instrument = None then [] else [ "instrument" ]
  in
  (pred, restricted_by)

(* Duration's own conditioning combines the instrument-range predicate above
   with, when [Ent] has already resolved and DUR-ENTRY requires it, a
   size-relation predicate against the already-known entry delay. *)
let dur_pred_from ~instr_arr proto dur_relation =
  let range_pred =
    match proto.instrument with
    | Some (Instrument { durations; _ }) -> duration_range_ok durations
    | None ->
        fun d ->
          Array.exists
            (fun (Instrument { durations; _ }) -> duration_range_ok durations d)
            instr_arr
  in
  let entry_active =
    match dur_relation with
    | DurShorterThanEntry _ -> proto.entrydelay <> None
    | DurIndependent _ | DurEqualsEntry -> false
  in
  let pred =
    match (dur_relation, proto.entrydelay) with
    | DurShorterThanEntry _, Some (Entrydelay ed) ->
        fun (Duration d as dv) -> range_pred dv && d <= ed
    | _ -> range_pred
  in
  let restricted_by =
    (if proto.instrument = None then [] else [ "instrument" ])
    @ if entry_active then [ "entrydelay" ] else []
  in
  (pred, restricted_by)

let duration_note_mode = function
  | DurIndependent m -> m
  | DurEqualsEntry -> PerChord
  | DurShorterThanEntry m -> m

(* Entry delay's own conditioning: unconstrained, unless DUR-ENTRY requires
   it to follow duration (which must then already be known). *)
let ed_pred_from proto dur_relation =
  let pred =
    match (dur_relation, proto.duration) with
    | DurShorterThanEntry _, Some (Shared (Duration d)) ->
        fun (Entrydelay ed) -> ed >= d
    | DurShorterThanEntry _, Some (PerNote ds) ->
        let max_d =
          ds |> List.map (fun (Duration d) -> d) |> List.fold_left Float.max 0.0
        in
        fun (Entrydelay ed) -> ed >= max_d
    | _ -> Fun.const true
  in
  let restricted_by =
    match dur_relation with
    | DurShorterThanEntry _ when proto.duration <> None -> [ "duration" ]
    | DurShorterThanEntry _ | DurIndependent _ | DurEqualsEntry -> []
  in
  (pred, restricted_by)

let register_is_percussion = function
  | PercussionRegister -> true
  | PitchRegister _ -> false

(* [Reg]'s predicate (EMR-3 fig 7-6): conditioned on both [Ins] (via the
   instrument's pitch range, mirroring [mode_pred_from_instrument]) and [Har]
   (percussion-agreement with the already-resolved relative pitch, when
   [Har] ran first). When the *other* side is [PerNote] this requires
   agreement with every one of its values rather than the one at the
   matching note index - the same conservative "must satisfy all" choice
   [ins_pred_from] already makes for per-note performance/dynamics/duration,
   since [resolve_note_param]'s per-note draws share one static predicate
   across all [n] notes. *)
let reg_pred_from ~instr_arr proto =
  let instr_pred =
    match proto.instrument with
    | Some (Instrument { pitchrange; _ }) ->
        register_compatible_with_pitch_range pitchrange
    | None ->
        fun r ->
          Array.exists
            (fun (Instrument { pitchrange; _ }) ->
              register_compatible_with_pitch_range pitchrange r)
            instr_arr
  in
  let harmony_pred =
    match proto.harmony with
    | None -> Fun.const true
    | Some (Shared h) ->
        fun r -> register_is_percussion r = row_value_is_percussion h
    | Some (PerNote hs) ->
        fun r ->
          List.for_all
            (fun h -> register_is_percussion r = row_value_is_percussion h)
            hs
  in
  let restricted_by =
    (if proto.instrument = None then [] else [ "instrument" ])
    @ if proto.harmony = None then [] else [ "harmony" ]
  in
  ((fun r -> instr_pred r && harmony_pred r), restricted_by)

(* [Har]'s predicate: percussion-agreement with the already-resolved
   [Reg] (when [Reg] ran first) - see [reg_pred_from] above for the
   PerNote/"must satisfy all" caveat, which applies symmetrically here. No
   direct dependence on [Ins]: relative pitch doesn't depend on which
   instrument plays it, only REGISTER mediates that (EMR-3 §7.1). *)
let har_pred_from proto =
  let pred =
    match proto.register with
    | None -> Fun.const true
    | Some (Shared r) ->
        fun h -> row_value_is_percussion h = register_is_percussion r
    | Some (PerNote rs) ->
        fun h ->
          List.for_all
            (fun r -> row_value_is_percussion h = register_is_percussion r)
            rs
  in
  let restricted_by = if proto.register = None then [] else [ "register" ] in
  (pred, restricted_by)

(* One step of the INTERVAL principle. [pred] is the external (register/
   instrument percussion-agreement) predicate - condition (2); condition
   (1) (forbidden tones, XCL-FRQ, never relaxed) and (3) (postponement -
   prefer a tone not sounded since the last reset, which happens once every
   producible tone has appeared at least once) are handled internally.
   Relaxation order, per the manual ("ignored in reverse order"): try
   (1+2+3) together; drop 3 (repeats allowed, still fine); drop 2 too
   (register/instrument mismatch, flagged via the first returned [bool] -
   mirrors ROW's own not-ok flag exactly); if even *that* leaves nothing
   (the given interval's matrix row has no allowed column at all, or every
   allowed column leads to a forbidden tone) - "INTERVAL RESTRICTIONS TOO
   STRICT", flagged via the second returned [bool] and kept separate from
   the first, since this is a distinct failure mode from a register/
   instrument mismatch and gets its own comment (see [note_problems]). *)
let interval_next ~tr ~(matrix : interval_matrix) ~forbidden ~pred ~phase
    ~seen_since_reset : row_value * bool * bool * interval_phase * Pitch_set.t =
  let (IntervalMatrix m) = matrix in
  let is_forbidden t = List.mem t forbidden in
  let producible = tr - List.length (List.sort_uniq compare forbidden) in
  let row_has_successor i = Array.exists (fun x -> x) m.(i - 1) in
  let row_successors i =
    List.init (tr - 1) (fun j -> j + 1)
    |> List.filter (fun j -> m.(i - 1).(j - 1))
  in
  (* ALEA among whichever candidates [admits] lets through - not just the
     first in list order, since more than one tone/interval may qualify. *)
  let pick_from ~admits candidates =
    match List.filter (fun (_, t) -> admits t) candidates with
    | [] -> None
    | valid -> Some (choose_lst valid)
  in
  let pick candidates =
    let ok_full (Step s as t) =
      (not (is_forbidden t))
      && pred (Tone t)
      && not (Pitch_set.mem s seen_since_reset)
    in
    let ok_no_postpone t = (not (is_forbidden t)) && pred (Tone t) in
    let ok_forbidden_only t = not (is_forbidden t) in
    match pick_from ~admits:ok_full candidates with
    | Some (p, t) -> Some (p, t, true)
    | None -> (
        match pick_from ~admits:ok_no_postpone candidates with
        | Some (p, t) -> Some (p, t, true)
        | None -> (
            match pick_from ~admits:ok_forbidden_only candidates with
            | Some (p, t) -> Some (p, t, false)
            | None -> None))
  in
  let remember (Step s) seen =
    let seen' = Pitch_set.add s seen in
    if Pitch_set.cardinal seen' >= producible then Pitch_set.empty else seen'
  in
  (* Degenerate matrix (or, for the very first tone, every tone forbidden) -
     validated against at formula-load time, but the runtime still needs to
     produce *something* rather than loop forever or crash. Picks interval 1
     regardless of the matrix or forbidden-tones list, flagged not-ok via
     [harmony_matrix_ok]. *)
  let too_strict_fallback base = transpose_step ~tr 1 base in
  match phase with
  | NotStarted -> (
      let candidates = List.init tr (fun i -> (i + 1, Step (i + 1))) in
      match pick candidates with
      | Some (_, t, ok) ->
          let seen' = remember t seen_since_reset in
          (Tone t, ok, true, HaveTone t, seen')
      | None ->
          let t = Step 1 in
          let seen' = remember t seen_since_reset in
          (Tone t, true, false, HaveTone t, seen'))
  | HaveTone base -> (
      let candidates =
        List.init (tr - 1) (fun i -> i + 1)
        |> List.filter row_has_successor
        |> List.map (fun i -> (i, transpose_step ~tr i base))
      in
      match pick candidates with
      | Some (i, t, ok) ->
          let seen' = remember t seen_since_reset in
          (Tone t, ok, true, HaveTransition (t, i), seen')
      | None ->
          let t = too_strict_fallback base in
          let seen' = remember t seen_since_reset in
          (Tone t, true, false, HaveTransition (t, 1), seen'))
  | HaveTransition (base, given) -> (
      let candidates =
        row_successors given
        |> List.map (fun i -> (i, transpose_step ~tr i base))
      in
      match pick candidates with
      | Some (i, t, ok) ->
          let seen' = remember t seen_since_reset in
          (Tone t, ok, true, HaveTransition (t, i), seen')
      | None ->
          let t = too_strict_fallback base in
          let seen' = remember t seen_since_reset in
          (Tone t, true, false, HaveTransition (t, 1), seen'))

(* One step of HARMONY's CHORD principle: draws the next chord (SEQ-CHORD,
   unconditioned - order-of-chords has no predicate to satisfy, exactly like
   [resolve_layer_autonomous]'s own unconditioned density-target draw),
   transposes it by whatever cumulative offset is currently in effect, and
   advances that offset once a full "pass" (one draw per table entry) has
   elapsed. Never invoked with anything but [HarChord] - the type still has
   to cover every [har_state_t] constructor, so the other two are dead
   branches here, mirrored by [chord_next]'s own callers never reaching
   them either. *)
let chord_to_string (Chord tones) =
  tones |> Array.to_list |> List.map row_value_to_string |> String.concat ","

let chord_next ?ctx (state : har_state_t) : chord * har_state_t =
  match state with
  | HarChord
      { tr; table; order_state; cumulative; drawn_since_pass; trans_intervals }
    ->
      let picked, order_state' =
        sel_draw ?ctx ~to_string:chord_to_string order_state
      in
      let transposed = transpose_chord ~tr cumulative picked in
      let drawn' = drawn_since_pass + 1 in
      let cumulative', drawn'', trans_intervals' =
        if drawn' >= Array.length table then
          match trans_intervals () with
          | Seq.Cons (k, rest) -> ((cumulative + k) mod tr, 0, rest)
          | Seq.Nil -> (cumulative, 0, trans_intervals)
          (* unreachable: infinite *)
        else (cumulative, drawn', trans_intervals)
      in
      ( transposed,
        HarChord
          {
            tr;
            table;
            order_state = order_state';
            cumulative = cumulative';
            drawn_since_pass = drawn'';
            trans_intervals = trans_intervals';
          } )
  | HarRow _ | HarInterval _ -> assert false

(* One hierarchy element's worth of work for one entry. This is the single
   place that knows how [Ins]/[Ent]/[Dur]/[Per]/[Dyn] each condition on, or
   get conditioned by, one another - both density modes below just fold this
   over the composer's [hierarchy] list once per entry. *)
(* [max_notes], when given, caps how many notes [Ins] may claim for this
   sub-pick - the remaining density budget still needed to fill the current
   chord (EMR-3 8.16: "the chord size of the instrument last selected is
   reduced if necessary to the remaining number of tones"). Passed by
   [fill_subpicks] (both density modes that score a chord from several
   sub-picks); [None] everywhere else (a single, ungrouped entry under
   [InstrumentDensity] has no target to cap against - its own chordsize
   simply *is* the note count).

   This must happen here, at the point [nr_of_notes] is first decided -
   rather than trimming it back down afterward, once the group's total is
   known - because every per-note field below (Reg/Har/Per/Dyn/Dur, whichever
   of them are still in this fold) draws exactly [nr_of_notes] independent
   values right here, in this same pass. Trimming only the *count* afterward
   still leaves those extra values already drawn: harmless for a value with
   no memory (Alea, Ratio), but for anything with continuity across draws -
   most of all HARMONY's row/matrix, an explicitly composer-designed
   sequence - the discarded extra draws still advanced the underlying state,
   so the *next* entry silently continues from wherever the wasted draws left
   off instead of from the one note actually kept. Capping at the source
   means never drawing more than will be used, so nothing is ever silently
   discarded and no state ever advances further than what's visible in the
   score. *)
(* [Har]'s own resolution step, extracted as a standalone function so it can
   be reused both from [resolve_step]'s [Har] case (unchanged) and from the
   merged, cross-layer pass union = common-harmony (EMR-3 6.2's "s=1")
   requires - see [resolve_common_harmony_merged]. Reads/writes only
   [states.har_state] and [proto.register]/[proto.nr_of_notes]; no other
   hierarchy element's state and no layer-identity dependency of any kind,
   so lifting it out here is pure code motion, not a behavior change. *)
let resolve_harmony (states : continuing_state) (proto : proto) :
    continuing_state * proto =
  (* EMR-3 fig 7-6: "if REGISTER precedes HARMONY, a 0-pitch is selected
     for the 0,0 register" - once [Reg] has already fixed a percussion
     register, HARMONY's role is trivial and the row stream isn't
     consumed at all for this entry (it stays in sync for the *next*
     entry, whichever value it would have produced here is simply never
     needed). Otherwise pull the next row value(s) as normal - [Har]'s
     only conditioning is the symmetric check in [har_pred_from], for
     when [Reg] hasn't run yet but did contain a percussion pick. *)
  let forced_percussion =
    match proto.register with
    | Some (Shared PercussionRegister) -> true
    | Some (PerNote rs) -> List.for_all register_is_percussion rs
    | _ -> false
  in
  if forced_percussion then
    let n = Option.value proto.nr_of_notes ~default:1 in
    let v, oks =
      ( PerNote (List.init n (fun _ -> RowPercussion)),
        PerNote (List.init n (fun _ -> true)) )
    in
    ( states,
      {
        proto with
        harmony = Some v;
        harmony_ok = Some oks;
        harmony_matrix_ok = Some oks;
      } )
  else
    let pred, _restricted_by = har_pred_from proto in
    let n = Option.value proto.nr_of_notes ~default:1 in
    (* EMR-3's ROW (entry 19) and INTERVAL (entries 21-24) have no "per
       chord" call number between them: every note in a chord always
       gets its own successive value, ignoring the entry-point boundary
       entirely. (A genuine shared-per-chord harmony is a distinct,
       not-yet-implemented CHORD principle, not a mode of either.) *)
    match states.har_state with
    | HarRow seq ->
        (* [row_stream] is infinite (it keeps re-transposing once the row
           is used up), but every pass preserves which entries are
           [RowPercussion] vs [Tone] - a composer-written row with no
           [Tone] at all (or none at all matching a fixed non-percussion
           register) would make [pred] unsatisfiable forever. Cap the
           search instead of risking an infinite loop; beyond the cap,
           accept the next value anyway and flag it not-ok, mirroring
           EMR-3's own "wrong pitch... provided with a comment"
           fallback. *)
        let max_tries = 10_000 in
        let draw_one st =
          let rec try_next tries st =
            let hd, tl =
              match Seq.uncons st with
              | Some (hd, tl) -> (hd, tl)
              | None -> assert false
            in
            if pred hd then (hd, tl, true)
            else if tries >= max_tries then (hd, tl, false)
            else try_next (tries + 1) tl
          in
          try_next 0 st
        in
        let vs, oks, seq' =
          List.init n (fun _ -> ())
          |> List.fold_left
               (fun (acc, oks_acc, st) () ->
                 let hd, tl, ok = draw_one st in
                 (hd :: acc, ok :: oks_acc, tl))
               ([], [], seq)
        in
        let v = PerNote (List.rev vs) and oks = PerNote (List.rev oks) in
        ( { states with har_state = HarRow seq' },
          {
            proto with
            harmony = Some v;
            harmony_ok = Some oks;
            harmony_matrix_ok = Some (PerNote (List.init n (fun _ -> true)));
          } )
    | HarInterval { tr; matrix; forbidden; phase; seen_since_reset } ->
        let vs, oks, matrix_oks, phase', seen' =
          List.init n (fun _ -> ())
          |> List.fold_left
               (fun (acc, oks_acc, matrix_oks_acc, phase, seen) () ->
                 let v, ok, matrix_ok, phase', seen' =
                   interval_next ~tr ~matrix ~forbidden ~pred ~phase
                     ~seen_since_reset:seen
                 in
                 ( v :: acc,
                   ok :: oks_acc,
                   matrix_ok :: matrix_oks_acc,
                   phase',
                   seen' ))
               ([], [], [], phase, seen_since_reset)
        in
        let v = PerNote (List.rev vs)
        and oks = PerNote (List.rev oks)
        and matrix_oks = PerNote (List.rev matrix_oks) in
        ( {
            states with
            har_state =
              HarInterval
                {
                  tr;
                  matrix;
                  forbidden;
                  phase = phase';
                  seen_since_reset = seen';
                };
          },
          {
            proto with
            harmony = Some v;
            harmony_ok = Some oks;
            harmony_matrix_ok = Some matrix_oks;
          } )
    | HarChord _ ->
        (* Unreachable: [Har] never appears in [subpick_hierarchy] under
           CHORD (see [resolve_layer_chord_density]) - its value is
           always a whole-group fact, seeded into every sub-pick before
           its own fold runs, never drawn inside [resolve_step] itself. *)
        assert false

let instrument_to_string (Instrument { instrument = InstrumentName n; _ }) = n
let entrydelay_to_string (Entrydelay ed) = Printf.sprintf "%.3f" ed
let duration_to_string (Duration d) = Printf.sprintf "%.3f" d

(* A short summary, not the full pitch range - good enough to label a GROUP
   repetition's element in a debug event; the range itself is static formula
   content the debug stream deliberately avoids repeating (see
   "manuals and notes/debug_output.md"'s "avoid just repeating the same
   static information for each parameter"). *)
let register_to_string = function
  | PercussionRegister -> "percussion"
  | PitchRegister _ -> "pitched"

(* Reports [restricted_by] (from one of the [*_pred_from] functions above) as
   a [Restriction] event when non-empty - i.e. only when this draw is
   actually conditioned on something, never for an unconstrained one. *)
let emit_restriction ~(ctx : Debug_log.context) restricted_by =
  if restricted_by <> [] then
    Debug_log.emit (fun () -> Debug_log.Restriction { ctx; restricted_by })

let resolve_step ~(ctx : Debug_log.context) ~perf_mode ~dyn_mode ~dur_relation
    ~reg_mode ?max_notes ?(used = []) (states, proto) elem =
  match elem with
  | Ins ->
      let ctx = { ctx with Debug_log.param = PIns } in
      let pred, restricted_by = ins_pred_from proto in
      emit_restriction ~ctx restricted_by;
      (* [used] is every instrument already picked earlier in the same chord
         (empty outside a multi-sub-pick group). Prefer one not in [used] -
         if at least one otherwise-compatible instrument is still unused,
         draw only from those, so a repeat never happens just because the
         ensemble happened to land on it again by chance. Only when every
         compatible instrument is already used do we fall back to drawing
         from all of them and flag the pick as [instrument_repeated] - EMR-3
         8.16's actual "not enough instruments" case. *)
      let has_unused =
        Array.exists (fun i -> pred i && not (List.mem i used)) states.instr_arr
      in
      let pred' i = pred i && ((not has_unused) || not (List.mem i used)) in
      let v, instr_state' =
        sel_sample_pred ~ctx ~to_string:instrument_to_string pred'
          states.instr_state
      in
      let (Instrument { chordsize = Chordsize { minsize; maxsize }; _ }) = v in
      let n_raw =
        if minsize = maxsize then minsize
        else Random.int (maxsize - minsize + 1) + minsize
      in
      let n = match max_notes with Some m -> min n_raw m | None -> n_raw in
      ( { states with instr_state = instr_state' },
        {
          proto with
          instrument = Some v;
          nr_of_notes = Some n;
          instrument_repeated = not has_unused;
        } )
  | Ent -> (
      let ctx = { ctx with Debug_log.param = PEnt } in
      match (dur_relation, proto.duration) with
      | DurEqualsEntry, Some (Shared (Duration d)) ->
          (states, { proto with entrydelay = Some (Entrydelay d) })
      | DurEqualsEntry, None ->
          (* [Dur] hasn't resolved yet, so it will just copy this entry delay
             through verbatim (below) - constrain the draw itself to what the
             instrument can sustain as a duration, rather than drawing freely
             and clamping afterwards, which would silently break the
             "duration = entry delay" invariant this mode promises. *)
          let dur_pred, restricted_by =
            dur_pred_from ~instr_arr:states.instr_arr proto dur_relation
          in
          emit_restriction ~ctx restricted_by;
          let pred (Entrydelay ed) = dur_pred (Duration ed) in
          let v, ed_state' =
            sel_sample_pred_tagged ~ctx ~to_string:entrydelay_to_string
              pred states.ed_state
          in
          let ok = result_ok v in
          ( { states with ed_state = ed_state' },
            {
              proto with
              entrydelay = Some (get_value v);
              duration_ok = Some (Shared ok);
            } )
      | _ ->
          let pred, restricted_by = ed_pred_from proto dur_relation in
          emit_restriction ~ctx restricted_by;
          let v, ed_state' =
            sel_sample_pred ~ctx ~to_string:entrydelay_to_string pred
              states.ed_state
          in
          ( { states with ed_state = ed_state' },
            { proto with entrydelay = Some v } ))
  | Dur -> (
      let ctx = { ctx with Debug_log.param = PDur } in
      match (dur_relation, proto.entrydelay) with
      | DurEqualsEntry, Some (Entrydelay ed) ->
          (* [Ent] already constrained this draw to the instrument's duration
             range (and tagged [duration_ok] accordingly) when it ran before
             [Dur] - just copy it through so the equality this mode promises
             actually holds, instead of re-clamping it here. *)
          ( states,
            {
              proto with
              duration = Some (Shared (Duration ed));
              duration_ok =
                Some (Option.value proto.duration_ok ~default:(Shared true));
            } )
      | _ ->
          let mode = duration_note_mode dur_relation in
          let pred, restricted_by =
            dur_pred_from ~instr_arr:states.instr_arr proto dur_relation
          in
          emit_restriction ~ctx restricted_by;
          let v, oks, dur_state' =
            resolve_note_param_tagged ~ctx ~to_string:duration_to_string mode
              proto.nr_of_notes pred states.dur_state
          in
          ( { states with dur_state = dur_state' },
            { proto with duration = Some v; duration_ok = Some oks } ))
  | Per ->
      let ctx = { ctx with Debug_log.param = PPer } in
      let pred, restricted_by =
        mode_pred_from_instrument ~instr_arr:states.instr_arr
          ~mem:Performance_modes.mem proto.instrument
          (fun (Instrument { performance; _ }) -> performance)
      in
      emit_restriction ~ctx restricted_by;
      let v, perf_state' =
        resolve_note_param ~ctx ~to_string:Performance.to_string perf_mode
          proto.nr_of_notes pred states.perf_state
      in
      ( { states with perf_state = perf_state' },
        { proto with performance = Some v } )
  | Dyn ->
      let ctx = { ctx with Debug_log.param = PDyn } in
      let pred, restricted_by =
        mode_pred_from_instrument ~instr_arr:states.instr_arr
          ~mem:Dynamic_modes.mem proto.instrument
          (fun (Instrument { dynamics; _ }) -> dynamics)
      in
      emit_restriction ~ctx restricted_by;
      let v, dyn_state' =
        resolve_note_param ~ctx ~to_string:Dynamic.to_string dyn_mode
          proto.nr_of_notes pred states.dyn_state
      in
      ({ states with dyn_state = dyn_state' }, { proto with dynamic = Some v })
  | Reg ->
      let ctx = { ctx with Debug_log.param = PReg } in
      let pred, restricted_by =
        reg_pred_from ~instr_arr:states.instr_arr proto
      in
      emit_restriction ~ctx restricted_by;
      let v, oks, reg_state' =
        resolve_note_param_tagged ~ctx ~to_string:register_to_string reg_mode
          proto.nr_of_notes pred states.reg_state
      in
      ( { states with reg_state = reg_state' },
        { proto with register = Some v; register_ok = Some oks } )
  | Har -> resolve_harmony states proto

let resolve_entry ?(start = empty_proto) ~ctx ~hierarchy ~perf_mode ~dyn_mode
    ~dur_relation ~reg_mode ?max_notes ?used states =
  List.fold_left
    (resolve_step ~ctx ~perf_mode ~dyn_mode ~dur_relation ~reg_mode ?max_notes
       ?used)
    (states, start) hierarchy

(** With [InstrumentDensity], every entry is its own timepoint - one instrument,
    one already-resolved entry delay. Each is wrapped as a singleton group so
    step 2 can treat both density modes uniformly. *)
let resolve_layer_instrument_density ~variant ~layer ~n_events ~hierarchy
    ~perf_mode ~dyn_mode ~dur_relation ~reg_mode states0 =
  let final_states, groups =
    List.init n_events (fun i -> i)
    |> List.fold_left
         (fun (states, acc) seq ->
           let ctx : Debug_log.context =
             { variant; layer; seq = Resolved seq; param = PIns }
           in
           let states', proto =
             resolve_entry ~ctx ~hierarchy ~perf_mode ~dyn_mode ~dur_relation
               ~reg_mode states
           in
           let ed =
             match proto.entrydelay with
             | Some ed -> ed
             | None -> Entrydelay 0.0
           in
           (advance_all_windows states', (ed, [ proto ]) :: acc))
         (states0, [])
  in
  (List.rev groups, final_states)

(* ============================================================
   Hierarchy plan: one ordered recipe per layer, shared by every density
   mode that fills a chord from one or more instrument sub-picks
   (autonomous and chord density - instrument density needs none of this,
   see [resolve_layer_instrument_density] above).

   A parameter set to per-chord is drawn once for the whole chord and
   copied to every note in it, rather than drawn separately per note. The
   plan below turns the composer's own ordered [hierarchy] into a recipe
   that says, for every element in turn, whether it's decided once for the
   whole entry or once per instrument - so that "before or after Ins"
   becomes a fact read off a step's position in this list, rather than a
   family of independently-computed booleans re-derived by hand at every
   call site (see "manuals and notes/analysis of score generation
   module.md"). *)

(* One step of the plan, in the same relative order as the composer's own
   [hierarchy]. [ComputeEntryValues] names a hierarchy element decided once
   for the whole entry, at exactly the position its own entry occupies
   relative to every other element. [ComputeNotesForInstrument] appears
   exactly once, standing in for [Ins]: it is the recipe for one
   instrument's own note(s) - whichever hierarchy elements are still
   per-note, in their own relative order (this is what used to be called
   [subpick_hierarchy]). *)
type plan_step =
  | ComputeEntryValues of hierarchy_elem
  | ComputeNotesForInstrument of hierarchy

type hierarchy_plan = plan_step list

type elem_role = EntryLevel | InstrumentLevel | StrategyManaged

(* Where a given hierarchy element's value is actually decided. [Ins] is
   never entry-level - its position in the plan IS the pivot from
   entry-level work to per-instrument work. [Ent] is entry-level unless
   [DurEqualsEntry], in which case entry delay and duration are a single
   coupled fact resolved by [fill_duration_equals_entry] below, outside the
   generic per-element mechanism entirely - not reducible to "drawn once,
   before or after the pivot" (see the analysis doc's "this doesn't quite
   cover DurEqualsEntry"). [Har] is entry-level only under chord density -
   the drawn chord itself IS harmony (see [chord_next]), never resolved via
   a plain predicate draw the way [Per]/[Dyn]/[Reg]/[Dur] are, so it too is
   [StrategyManaged] rather than a normal plan step; everywhere else it
   stays per-note ([resolve_harmony] via ROW/INTERVAL). *)
let classify_elem ~is_chord_density ~perf_mode ~dyn_mode ~dur_relation
    ~reg_mode : hierarchy_elem -> elem_role = function
  | Ins -> InstrumentLevel
  | Ent -> if dur_relation = DurEqualsEntry then StrategyManaged else EntryLevel
  | Har -> if is_chord_density then StrategyManaged else InstrumentLevel
  | Per -> if perf_mode = PerChord then EntryLevel else InstrumentLevel
  | Dyn -> if dyn_mode = PerChord then EntryLevel else InstrumentLevel
  | Reg -> if reg_mode = PerChord then EntryLevel else InstrumentLevel
  | Dur ->
      if dur_relation = DurEqualsEntry then InstrumentLevel
        (* stays per-note - [resolve_step]'s own [Dur] case already copies
           it from a seeded entry delay when one is present, exactly as
           every other per-note element would read an already-fixed value *)
      else if duration_note_mode dur_relation = PerChord then EntryLevel
      else InstrumentLevel

type compiled_hierarchy = {
  plan : hierarchy_plan;
  subpick_hierarchy : hierarchy;
  dur_equals_entry : bool;
  ent_before_dur : bool; (* only meaningful when [dur_equals_entry] *)
  perf_extracted : bool;
  perf_before_ins : bool;
  dyn_extracted : bool;
  dyn_before_ins : bool;
  reg_extracted : bool;
  reg_before_ins : bool;
  dur_extracted : bool; (* always [false] when [dur_equals_entry] *)
  dur_before_ins : bool;
}

(* Built once per layer from the composer's [hierarchy] - everything every
   consumer below needs, derived by walking [hierarchy] exactly once rather
   than independently re-deriving fragments of it per density mode (as the
   two functions this replaces used to). *)
let compile_hierarchy ~is_chord_density ~perf_mode ~dyn_mode ~dur_relation
    ~reg_mode (hierarchy : hierarchy) : compiled_hierarchy =
  let role =
    classify_elem ~is_chord_density ~perf_mode ~dyn_mode ~dur_relation
      ~reg_mode
  in
  let subpick_hierarchy = hierarchy |> List.filter (fun e -> role e = InstrumentLevel) in
  let plan =
    hierarchy
    |> List.filter_map (fun e ->
        match role e with
        | EntryLevel -> Some (ComputeEntryValues e)
        | InstrumentLevel when e = Ins ->
            Some (ComputeNotesForInstrument subpick_hierarchy)
        | InstrumentLevel | StrategyManaged -> None)
  in
  let pivot_index =
    let rec go i = function
      | [] -> assert false (* [Ins] is always in [hierarchy] *)
      | ComputeNotesForInstrument _ :: _ -> i
      | ComputeEntryValues _ :: rest -> go (i + 1) rest
    in
    go 0 plan
  in
  let before_ins elem =
    let rec go i = function
      | [] -> false (* [elem] isn't entry-level at all *)
      | ComputeEntryValues e :: _ when e = elem -> i < pivot_index
      | _ :: rest -> go (i + 1) rest
    in
    go 0 plan
  in
  let index_of x =
    let rec go i = function
      | [] -> assert false
      | y :: rest -> if y = x then i else go (i + 1) rest
    in
    go 0 hierarchy
  in
  {
    plan;
    subpick_hierarchy;
    dur_equals_entry = dur_relation = DurEqualsEntry;
    ent_before_dur = index_of Ent < index_of Dur;
    perf_extracted = role Per = EntryLevel;
    perf_before_ins = before_ins Per;
    dyn_extracted = role Dyn = EntryLevel;
    dyn_before_ins = before_ins Dyn;
    reg_extracted = role Reg = EntryLevel;
    reg_before_ins = before_ins Reg;
    dur_extracted = role Dur = EntryLevel;
    dur_before_ins = before_ins Dur;
  }

(* Whole-chord ([PerChord]) values already fixed before an instrument's own
   hierarchy fold runs, for whichever of performance/dynamics/register the
   composer's hierarchy puts before [Ins]. Duration is handled separately
   (inline in [fill_group_general]/[fill_duration_equals_entry]) since its
   own extraction also depends on entry delay's timing, not just [Ins]'s -
   [register]/[duration] additionally carry their "_ok" flag alongside the
   value, since (unlike performance/dynamic) [proto] tracks whether each was
   an [Impossible] fallback. *)
type chord_seeds = {
  cs_perf : Performance.t note_value option;
  cs_dyn : Dynamic.t note_value option;
  cs_reg : (register note_value * bool note_value) option;
  cs_dur : (duration note_value * bool note_value) option;
  (* CHORD only: a dummy percussion/pitched marker, seeded before an
     instrument's own fold runs so [Ins]/[Reg]'s existing percussion-
     agreement predicates ([ins_pred_from]'s [from_harmony], [reg_pred_from]'s
     [harmony_pred]) fire correctly even though [Har] itself never runs for
     an instrument's own turn under CHORD - overwritten with the real,
     sliced-from-the-drawn-chord per-note values afterward (see
     [assign_harmony] in [resolve_layer_chord_density]). Always [None] for
     [Autonomous], where it is simply never consulted (every subpick
     resolves [Har] itself, per-note, via [resolve_harmony]). *)
  cs_harmony_seed : row_value note_value option;
}

(* One segment is a homogeneous run of instrument-picks filled to one target
   note count, sharing one harmony seed - autonomous density always has
   exactly one (the whole chord, no harmony seed); chord density has up to
   two, one per tone type (percussion, pitched), each seeded with the right
   marker so [Ins]/[Reg] agree with it. A segment with target 0 (the common
   case for an all-pitched or all-percussion chord) is skipped entirely
   rather than resolving a "phantom" zero-note instrument-pick, which would
   needlessly consume an instrument-selection-cycle draw. *)
type segment = { seg_target : int; seg_harmony_seed : row_value note_value option }

let instruments_of group =
  List.map
    (fun p -> match p.instrument with Some i -> i | None -> assert false)
    group

let max_duration_of proto =
  match proto.duration with
  | Some (Shared (Duration d)) -> d
  | Some (PerNote ds) ->
      ds |> List.map (fun (Duration d) -> d) |> List.fold_left Float.max 0.0
  | None -> 0.0

let force_not_ok = function
  | Shared _ -> Shared false
  | PerNote xs -> PerNote (List.map (fun _ -> false) xs)

(* Overrides [duration_ok] group-wide: used when the group's one shared
   entry delay itself turned out [Impossible], a chord-level fact that
   can't be pinned on any single instrument's own (otherwise-fine) draw. *)
let mark_group_ok ok proto =
  if ok then proto
  else { proto with duration_ok = Option.map force_not_ok proto.duration_ok }

let stamp_ok ok proto = { proto with duration_ok = Some (Shared ok) }
let keep_seed settled _ = settled

(* One instrument's own turn: seeds whatever [seeds] already fixes for the
   whole chord, then folds [subpick_hierarchy] (every hierarchy element
   still per-note) to resolve the rest. *)
let resolve_subpick ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode ~dur_relation
    ~reg_mode ?seed_entrydelay ?max_notes ?used ~(seeds : chord_seeds) states =
  let start =
    {
      empty_proto with
      entrydelay = seed_entrydelay;
      performance = seeds.cs_perf;
      dynamic = seeds.cs_dyn;
      register = Option.map fst seeds.cs_reg;
      register_ok = Option.map snd seeds.cs_reg;
      duration = Option.map fst seeds.cs_dur;
      duration_ok = Option.map snd seeds.cs_dur;
      harmony = seeds.cs_harmony_seed;
    }
  in
  resolve_entry ~ctx ~start ~hierarchy:subpick_hierarchy ~perf_mode ~dyn_mode
    ~dur_relation ~reg_mode ?max_notes ?used states

(* Resolves the instrument-picks that fill one segment to its target. [seed]
   is the entry delay already fixed for the whole group (if any) before the
   first pick runs; [next_seed] derives what becomes fixed for the *next*
   pick from what's fixed so far and the pick just resolved - used only by
   [DurEqualsEntry]'s "settle from the first pick" case, a no-op everywhere
   else. [used] tracks every instrument already picked earlier in this same
   segment, so a later pick draws from the unused ones whenever any remain
   (EMR-3 8.16), only falling back to a repeat - flagged
   [instrument_repeated] - once the orchestra has genuinely run out. *)
let fill_subpicks ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode ~dur_relation
    ~reg_mode states target ~seed ~next_seed ~seeds =
  let rec loop states total used acc settled =
    let states', proto =
      resolve_subpick ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode
        ~dur_relation ~reg_mode ?seed_entrydelay:settled
        ~max_notes:(target - total) ~used ~seeds states
    in
    let picked =
      match proto.instrument with Some i -> i | None -> assert false
    in
    let settled' = next_seed settled proto in
    let n = Option.value proto.nr_of_notes ~default:1 in
    let total' = total + n in
    let used' = picked :: used in
    (* Trim in case the pick overshot the target note count. *)
    if total' >= target then
      let proto' = { proto with nr_of_notes = Some (n - (total' - target)) } in
      (settled', List.rev (proto' :: acc), states')
    else loop states' total' used' (proto :: acc) settled'
  in
  loop states 0 [] [] seed

(* Fills every segment in turn, threading [seed]/[next_seed] across ALL of
   them - [DurEqualsEntry]'s own "first instrument decides the whole
   chord's entry delay" needs this so the very first instrument built,
   across every segment, is the one that settles it, regardless of which
   segment it happens to fall in (percussion or pitched). *)
let fill_segments ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode ~dur_relation
    ~reg_mode states (segments : (segment * chord_seeds) list) ~seed
    ~next_seed =
  segments
  |> List.fold_left
       (fun (seed, group_acc, states) (seg, seeds) ->
         if seg.seg_target <= 0 then (seed, group_acc, states)
         else
           let settled, group, states' =
             fill_subpicks ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode
               ~dur_relation ~reg_mode states seg.seg_target ~seed ~next_seed
               ~seeds
           in
           (settled, group_acc @ group, states'))
       (seed, [], states)

(* Draws duration's own whole-chord value using whatever of its two
   dependencies (the instrument, entry delay) is fixed at the point this is
   called from - [ed_opt] carries entry delay when it's already decided,
   [None] otherwise. Reuses [dur_pred_from] exactly as a single instrument's
   own [Dur] step would, just fed a placeholder proto with only
   [entrydelay] (maybe) set. *)
let draw_duration_before ~ctx ~dur_relation ~ed_opt states =
  let ctx = { ctx with Debug_log.param = PDur } in
  let pred, restricted_by =
    dur_pred_from ~instr_arr:states.instr_arr
      { empty_proto with entrydelay = ed_opt }
      dur_relation
  in
  emit_restriction ~ctx restricted_by;
  let v, dur_state' =
    sel_sample_pred_tagged ~ctx ~to_string:duration_to_string pred
      states.dur_state
  in
  let ok = result_ok v in
  let d = get_value v in
  ({ states with dur_state = dur_state' }, Some (Shared d, Shared ok))

(* The [Ins]-after-[Dur] counterpart: the group is already fully resolved
   (so every instrument is known), constrained to whatever of [ed_opt] is
   already fixed. *)
let stamp_duration_after ~ctx ~dur_relation ~ed_opt group states' =
  let ctx = { ctx with Debug_log.param = PDur } in
  let instruments = instruments_of group in
  let pred (Duration d as dv) =
    List.for_all
      (fun (Instrument { durations; _ }) -> duration_range_ok durations dv)
      instruments
    &&
    match (dur_relation, ed_opt) with
    | DurShorterThanEntry _, Some (Entrydelay ed) -> d <= ed
    | _ -> true
  in
  let v, dur_state' =
    sel_sample_pred_tagged ~ctx ~to_string:duration_to_string pred
      states'.dur_state
  in
  let ok = result_ok v in
  let d = get_value v in
  let group' =
    List.map
      (fun p ->
        { p with duration = Some (Shared d); duration_ok = Some (Shared ok) })
      group
  in
  (group', { states' with dur_state = dur_state' })

(* Shared tail of the two [Dur]-before-[Ent] branches: draw the group's
   entry delay from whatever duration(s) ended up in the (by now fully
   resolved, including duration) group. *)
let finish_with_computed_entrydelay ~ctx ~dur_relation group states' =
  let ctx = { ctx with Debug_log.param = PEnt } in
  let max_dur =
    group |> List.fold_left (fun acc p -> Float.max acc (max_duration_of p)) 0.0
  in
  let pred =
    match dur_relation with
    | DurShorterThanEntry _ -> fun (Entrydelay ed) -> ed >= max_dur
    | DurIndependent _ | DurEqualsEntry -> Fun.const true
  in
  let v, ed_state' =
    sel_sample_pred_tagged ~ctx ~to_string:entrydelay_to_string pred
      states'.ed_state
  in
  let ok = result_ok v in
  let ed = get_value v in
  let group = List.map (mark_group_ok ok) group in
  (ed, group, { states' with ed_state = ed_state' })

(* [DurEqualsEntry]'s own special case (see [classify_elem]): entry delay
   and duration are one coupled fact, decided independently of every other
   hierarchy element's own before/after-[Ins] position - not reducible to
   the generic "drawn once, before or after the pivot" mechanism every other
   entry-level element uses (see [fill_group_general] below). *)
let fill_duration_equals_entry ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode
    ~dur_relation ~reg_mode ~ent_before_dur states segments =
  if ent_before_dur then
    (* The drawn value becomes every instrument's duration verbatim, so -
       exactly like a single instrument's own case this generalizes - it
       must itself be achievable as *some* instrument's duration. *)
    let pred (Entrydelay ed) =
      fst (dur_pred_from ~instr_arr:states.instr_arr empty_proto dur_relation)
        (Duration ed)
    in
    let v, ed_state' =
      sel_sample_pred_tagged
        ~ctx:{ ctx with Debug_log.param = PEnt }
        ~to_string:entrydelay_to_string pred states.ed_state
    in
    let ok = result_ok v in
    let ed = get_value v in
    let states = { states with ed_state = ed_state' } in
    let _, group, states' =
      fill_segments ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode ~dur_relation
        ~reg_mode states segments ~seed:(Some ed) ~next_seed:keep_seed
    in
    (ed, List.map (stamp_ok ok) group, states')
  else
    let next_seed settled proto =
      match settled with
      | Some _ -> settled
      | None -> (
          match proto.duration with
          | Some (Shared (Duration d)) -> Some (Entrydelay d)
          | _ -> None)
    in
    let settled, group, states' =
      fill_segments ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode ~dur_relation
        ~reg_mode states segments ~seed:None ~next_seed
    in
    (* A chord could in principle have zero tones; fall back to a zero entry
       delay. *)
    let ed = Option.value settled ~default:(Entrydelay 0.0) in
    let ok =
      match group with
      | p :: _ -> (
          match p.duration_ok with Some (Shared ok) -> ok | _ -> true)
      | [] -> true
    in
    (ed, List.map (stamp_ok ok) group, states')

(* The general (non-[DurEqualsEntry]) case: entry delay and, when extracted,
   duration each resolve independently, before or after [Ins] per their own
   hierarchy position. *)
let fill_group_general ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode
    ~dur_relation ~reg_mode ~ent_before_dur ~dur_extracted ~dur_before_ins
    states segments =
  if ent_before_dur then
    let v, ed_state' =
      sel_sample_pred_tagged
        ~ctx:{ ctx with Debug_log.param = PEnt }
        ~to_string:entrydelay_to_string (Fun.const true) states.ed_state
    in
    let ed = get_value v in
    let states = { states with ed_state = ed_state' } in
    if dur_extracted && dur_before_ins then
      let states, dur_seed = draw_duration_before ~ctx ~dur_relation ~ed_opt:(Some ed) states in
      let segments' =
        segments |> List.map (fun (seg, seeds) -> (seg, { seeds with cs_dur = dur_seed }))
      in
      let _, group, states' =
        fill_segments ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode
          ~dur_relation ~reg_mode states segments' ~seed:(Some ed)
          ~next_seed:keep_seed
      in
      (ed, group, states')
    else
      let _, group, states' =
        fill_segments ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode
          ~dur_relation ~reg_mode states segments ~seed:(Some ed)
          ~next_seed:keep_seed
      in
      if dur_extracted then
        let group, states' = stamp_duration_after ~ctx ~dur_relation ~ed_opt:(Some ed) group states' in
        (ed, group, states')
      else (ed, group, states')
  else if dur_extracted && dur_before_ins then
    let states, dur_seed = draw_duration_before ~ctx ~dur_relation ~ed_opt:None states in
    let segments' =
      segments |> List.map (fun (seg, seeds) -> (seg, { seeds with cs_dur = dur_seed }))
    in
    let _, group, states' =
      fill_segments ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode ~dur_relation
        ~reg_mode states segments' ~seed:None ~next_seed:keep_seed
    in
    finish_with_computed_entrydelay ~ctx ~dur_relation group states'
  else
    let _, group, states' =
      fill_segments ~ctx ~subpick_hierarchy ~perf_mode ~dyn_mode ~dur_relation
        ~reg_mode states segments ~seed:None ~next_seed:keep_seed
    in
    let group, states' =
      if dur_extracted then stamp_duration_after ~ctx ~dur_relation ~ed_opt:None group states'
      else (group, states')
    in
    finish_with_computed_entrydelay ~ctx ~dur_relation group states'

(* One event's worth of chord-filling: given this event's already-decided
   segments (target note count + harmony seed per segment - always exactly
   one segment with no harmony seed for autonomous density; up to two, one
   per tone type, for chord density), resolves every entry-level parameter
   at its own hierarchy position, fills every segment's instruments, and
   returns the group's shared entry delay plus every note's proto.

   [split_reg_by_tone_type] is the one place the two density modes still
   genuinely differ once everything above is shared: when [Reg] is
   extracted *after* [Ins], autonomous density draws one shared register
   that must agree with every note's own already-resolved harmony
   simultaneously (today's behavior - this can go [Impossible] for a
   chord that happens to mix percussion and pitched tones, which ROW/
   INTERVAL can legitimately produce; preserved here unchanged, not "fixed",
   since that's a separate, unrequested behavior change), while chord
   density already knows its percussion/pitched split up front and always
   draws two independent registers, one per partition. *)
let resolve_group ~ctx (compiled : compiled_hierarchy) ~perf_mode ~dyn_mode
    ~dur_relation ~reg_mode ~split_reg_by_tone_type states
    (raw_segments : segment list) =
  let states, perf_seed =
    if compiled.perf_extracted && compiled.perf_before_ins then
      let ctx = { ctx with Debug_log.param = PPer } in
      let pred, restricted_by =
        mode_pred_from_instrument ~instr_arr:states.instr_arr
          ~mem:Performance_modes.mem None
          (fun (Instrument { performance; _ }) -> performance)
      in
      emit_restriction ~ctx restricted_by;
      let v, perf_state' =
        sel_sample_pred ~ctx ~to_string:Performance.to_string pred
          states.perf_state
      in
      ({ states with perf_state = perf_state' }, Some (Shared v))
    else (states, None)
  in
  let states, dyn_seed =
    if compiled.dyn_extracted && compiled.dyn_before_ins then
      let ctx = { ctx with Debug_log.param = PDyn } in
      let pred, restricted_by =
        mode_pred_from_instrument ~instr_arr:states.instr_arr
          ~mem:Dynamic_modes.mem None (fun (Instrument { dynamics; _ }) ->
            dynamics)
      in
      emit_restriction ~ctx restricted_by;
      let v, dyn_state' =
        sel_sample_pred ~ctx ~to_string:Dynamic.to_string pred states.dyn_state
      in
      ({ states with dyn_state = dyn_state' }, Some (Shared v))
    else (states, None)
  in
  let states, reg_seeds =
    (* One shared register per segment when [Reg] is entry-level-before-
       [Ins] - drawn per segment (not once for the whole event) because its
       predicate depends on that segment's own harmony seed (percussion vs.
       pitched, EMR-3 fig 7-6); autonomous always has exactly one segment
       with no harmony seed, so this degenerates to "drawn once" there,
       unchanged from before. *)
    if compiled.reg_extracted && compiled.reg_before_ins then
      let ctx = { ctx with Debug_log.param = PReg } in
      raw_segments
      |> List.fold_left
           (fun (states, acc) seg ->
             if seg.seg_target <= 0 then (states, None :: acc)
             else
               let pred, restricted_by =
                 reg_pred_from ~instr_arr:states.instr_arr
                   { empty_proto with harmony = seg.seg_harmony_seed }
               in
               emit_restriction ~ctx restricted_by;
               let v, reg_state' =
                 sel_sample_pred_tagged ~ctx ~to_string:register_to_string pred
                   states.reg_state
               in
               let ok = result_ok v in
               let r = get_value v in
               ( { states with reg_state = reg_state' },
                 Some (Shared r, Shared ok) :: acc ))
           (states, [])
      |> fun (states, acc) -> (states, List.rev acc)
    else (states, List.map (fun _ -> None) raw_segments)
  in
  let segments =
    List.map2
      (fun seg reg_seed ->
        ( seg,
          {
            cs_perf = perf_seed;
            cs_dyn = dyn_seed;
            cs_reg = reg_seed;
            cs_dur = None;
            cs_harmony_seed = seg.seg_harmony_seed;
          } ))
      raw_segments reg_seeds
  in
  let ed, group, states' =
    if compiled.dur_equals_entry then
      fill_duration_equals_entry ~ctx
        ~subpick_hierarchy:compiled.subpick_hierarchy ~perf_mode ~dyn_mode
        ~dur_relation ~reg_mode ~ent_before_dur:compiled.ent_before_dur states
        segments
    else
      fill_group_general ~ctx ~subpick_hierarchy:compiled.subpick_hierarchy
        ~perf_mode ~dyn_mode ~dur_relation ~reg_mode
        ~ent_before_dur:compiled.ent_before_dur
        ~dur_extracted:compiled.dur_extracted
        ~dur_before_ins:compiled.dur_before_ins states segments
  in
  let group, states' =
    if compiled.perf_extracted && not compiled.perf_before_ins then
      let ctx = { ctx with Debug_log.param = PPer } in
      let pred v =
        List.for_all
          (fun (Instrument { performance = modes; _ }) ->
            Performance_modes.mem v modes)
          (instruments_of group)
      in
      let v, perf_state' =
        sel_sample_pred ~ctx ~to_string:Performance.to_string pred
          states'.perf_state
      in
      ( List.map (fun p -> { p with performance = Some (Shared v) }) group,
        { states' with perf_state = perf_state' } )
    else (group, states')
  in
  let group, states' =
    if compiled.dyn_extracted && not compiled.dyn_before_ins then
      let ctx = { ctx with Debug_log.param = PDyn } in
      let pred v =
        List.for_all
          (fun (Instrument { dynamics = modes; _ }) ->
            Dynamic_modes.mem v modes)
          (instruments_of group)
      in
      let v, dyn_state' =
        sel_sample_pred ~ctx ~to_string:Dynamic.to_string pred states'.dyn_state
      in
      ( List.map (fun p -> { p with dynamic = Some (Shared v) }) group,
        { states' with dyn_state = dyn_state' } )
    else (group, states')
  in
  let group, states' =
    if compiled.reg_extracted && not compiled.reg_before_ins then
      let ctx = { ctx with Debug_log.param = PReg } in
      if split_reg_by_tone_type then
        let is_percussion_proto p =
          match p.harmony with
          | Some (Shared RowPercussion) -> true
          | _ -> false
        in
        let perc_group, pitched_group =
          List.partition is_percussion_proto group
        in
        let draw_for target_percussion sub_group states' =
          match sub_group with
          | [] -> (sub_group, states')
          | _ ->
              let pred v =
                register_is_percussion v = target_percussion
                && List.for_all
                     (fun (Instrument { pitchrange; _ }) ->
                       register_compatible_with_pitch_range pitchrange v)
                     (instruments_of sub_group)
              in
              let v, reg_state' =
                sel_sample_pred_tagged ~ctx ~to_string:register_to_string pred
                  states'.reg_state
              in
              let ok = result_ok v in
              let r = get_value v in
              ( List.map
                  (fun p ->
                    {
                      p with
                      register = Some (Shared r);
                      register_ok = Some (Shared ok);
                    })
                  sub_group,
                { states' with reg_state = reg_state' } )
        in
        let perc_group', states' = draw_for true perc_group states' in
        let pitched_group', states' = draw_for false pitched_group states' in
        (perc_group' @ pitched_group', states')
      else
        let pred v =
          let instr_ok =
            List.for_all
              (fun (Instrument { pitchrange; _ }) ->
                register_compatible_with_pitch_range pitchrange v)
              (instruments_of group)
          in
          let harmony_ok =
            group
            |> List.concat_map (fun p ->
                match p.harmony with
                | Some (PerNote hs) -> hs
                | Some (Shared h) -> [ h ]
                | None -> [])
            |> List.for_all (fun h ->
                register_is_percussion v = row_value_is_percussion h)
          in
          instr_ok && harmony_ok
        in
        let v, reg_state' =
          sel_sample_pred_tagged ~ctx ~to_string:register_to_string pred
            states'.reg_state
        in
        let ok = result_ok v in
        let r = get_value v in
        ( List.map
            (fun p ->
              {
                p with
                register = Some (Shared r);
                register_ok = Some (Shared ok);
              })
            group,
          { states' with reg_state = reg_state' } )
    else (group, states')
  in
  (ed, group, states')

(** With [Autonomous] density, each timepoint picks a target density using
    the composer's selection principle, then fills instruments (one segment,
    no harmony seed) until that target is reached. *)
let resolve_layer_autonomous ~variant ~layer ~n_events ~hierarchy ~perf_mode
    ~dyn_mode ~dur_relation ~reg_mode ~low ~high ~selection_principle states0 =
  let compiled =
    compile_hierarchy ~is_chord_density:false ~perf_mode ~dyn_mode
      ~dur_relation ~reg_mode hierarchy
  in
  let dens_arr =
    Array.init (high - low + 1) (fun i -> low + i) |> elements_of_array
  in
  let final_states, _, groups =
    List.init n_events (fun i -> i)
    |> List.fold_left
         (fun (states, dens_state, acc) seq ->
           let ctx : Debug_log.context =
             { variant; layer; seq = Resolved seq; param = PDensity }
           in
           let target, dens_state' =
             sel_sample ~ctx ~to_string:string_of_int dens_state
           in
           let ed, group, states' =
             resolve_group ~ctx compiled ~perf_mode ~dyn_mode ~dur_relation
               ~reg_mode ~split_reg_by_tone_type:false states
               [ { seg_target = target; seg_harmony_seed = None } ]
           in
           ( advance_all_windows states',
             sel_advance_window dens_state',
             (ed, group) :: acc ))
         (states0, sel_init selection_principle n_events dens_arr, [])
  in
  (List.rev groups, final_states)

(* HARMONY's CHORD principle (EMR-3 §8.2/§9.2):
  When you choose CHORD principle, the harmony is formed by picking chords from a table provided by the composer.
  You can choose what principle is used to pick the order chords are picked.
  You can also set a principle for transposing the chords.
  Using the chord principle, will also mean that vertical density per entry is controlled by the same principles.

  Chords are voiced by picking instruments until the required density for the chord is reached.
  (This works similar to autonomous density).

  Note that chords may also contain percussion notes, but these are not transposed.
*)
let resolve_layer_chord_density ~variant ~layer ~n_events ~hierarchy ~perf_mode
    ~dyn_mode ~dur_relation ~reg_mode states0 =
  let compiled =
    compile_hierarchy ~is_chord_density:true ~perf_mode ~dyn_mode
      ~dur_relation ~reg_mode hierarchy
  in
  let split_chord (Chord arr) =
    let tones = Array.to_list arr in
    let percussion_n =
      List.length (List.filter row_value_is_percussion tones)
    in
    let pitched_tones =
      List.filter (fun v -> not (row_value_is_percussion v)) tones
    in
    (percussion_n, pitched_tones)
  in
  (* Post-hoc slice-and-stamp pass, run once the whole group's [nr_of_notes]
     are final: each percussion instrument's tones all become
     [RowPercussion]; each pitched instrument consumes the next
     [nr_of_notes] tones off the shared, in-order [pitched_tones] list
     (which [fill_subpicks]' own target-trimming guarantees sums to exactly
     [List.length pitched_tones] across the pitched segment). Always fully
     "ok" - the group was engineered to exactly match the drawn chord; a
     genuine pitch/register mismatch can still surface as [pitch_ok = false]
     via [resolve_pitch], unchanged. *)
  let assign_harmony pitched_tones group =
    let all_true n = PerNote (List.init n (fun _ -> true)) in
    let rec go remaining = function
      | [] -> []
      | proto :: rest ->
          let n = Option.value proto.nr_of_notes ~default:1 in
          let is_percussion =
            match proto.harmony with
            | Some (Shared RowPercussion) -> true
            | _ -> false
          in
          let vals, remaining' =
            if is_percussion then
              (List.init n (fun _ -> RowPercussion), remaining)
            else
              let rec take acc n = function
                | l when n = 0 -> (List.rev acc, l)
                | x :: xs -> take (x :: acc) (n - 1) xs
                | [] -> (List.rev acc, [])
              in
              take [] n remaining
          in
          {
            proto with
            harmony = Some (PerNote vals);
            harmony_ok = Some (all_true n);
            harmony_matrix_ok = Some (all_true n);
          }
          :: go remaining' rest
    in
    go pitched_tones group
  in
  let final_states, groups =
    List.init n_events (fun i -> i)
    |> List.fold_left
         (fun (states, acc) seq ->
           let ctx : Debug_log.context =
             { variant; layer; seq = Resolved seq; param = PChordOrder }
           in
           let chord, har_state' = chord_next ~ctx states.har_state in
           let states = { states with har_state = har_state' } in
           let percussion_n, pitched_tones = split_chord chord in
           let raw_segments =
             [
               {
                 seg_target = percussion_n;
                 seg_harmony_seed = Some (Shared RowPercussion);
               };
               {
                 seg_target = List.length pitched_tones;
                 seg_harmony_seed = Some (Shared (Tone (Step 1)));
               };
             ]
           in
           let ed, group, states' =
             resolve_group ~ctx compiled ~perf_mode ~dyn_mode ~dur_relation
               ~reg_mode ~split_reg_by_tone_type:true states raw_segments
           in
           let group = assign_harmony pitched_tones group in
           (advance_all_windows states', (ed, group) :: acc))
         (states0, [])
  in
  (List.rev groups, final_states)

(* ---- Step 2: turn resolved protos into the final score (entries + notes) ---- *)

(* One sub-pick's own notes - no entry delay or time here yet, both are a
   property of the whole entry (see [entry_of_group]), not of one sub-pick. *)
let notes_of_proto proto : note list =
  let instr =
    match proto.instrument with
    | Some (Instrument { instrument; _ }) -> instrument
    | None -> assert false
  in
  let n = Option.value proto.nr_of_notes ~default:1 in
  let perf =
    match proto.performance with Some tv -> tv | None -> assert false
  in
  let dyn = match proto.dynamic with Some tv -> tv | None -> assert false in
  let dur = match proto.duration with Some tv -> tv | None -> assert false in
  let dur_ok =
    match proto.duration_ok with Some tv -> tv | None -> assert false
  in
  let reg = match proto.register with Some tv -> tv | None -> assert false in
  let reg_ok =
    match proto.register_ok with Some tv -> tv | None -> assert false
  in
  let har = match proto.harmony with Some tv -> tv | None -> assert false in
  let har_ok =
    match proto.harmony_ok with Some tv -> tv | None -> assert false
  in
  let har_matrix_ok =
    match proto.harmony_matrix_ok with Some tv -> tv | None -> assert false
  in
  List.init n (fun i ->
      let pitch, agree_ok = resolve_pitch (value_at reg i) (value_at har i) in
      let pitch_ok = agree_ok && value_at reg_ok i && value_at har_ok i in
      {
        time = 0.0;
        instrument = instr;
        performance = value_at perf i;
        dynamic = value_at dyn i;
        duration = value_at dur i;
        pitch;
        diagnostics =
          {
            duration_ok = value_at dur_ok i;
            pitch_ok;
            harmony_matrix_ok = value_at har_matrix_ok i;
            instrument_repeated = proto.instrument_repeated;
          };
        (* Overwritten by [entry_of_group] once every sub-pick's notes are
           concatenated and this note's real position within the whole
           chord is known - this placeholder is never observed outside
           that one function. *)
        id = Debug_log.placeholder_note_id;
      })

(* [Some v] iff every note in [notes] agrees on [v] - a display convenience
   for the entry header line, not a resolution-time tag (a group may combine
   several independently-resolved sub-picks, see [resolve_layer_autonomous]). *)
let uniform_value get = function
  | [] -> None
  | n0 :: rest ->
      let v0 = get n0 in
      if List.for_all (fun n -> get n = v0) rest then Some v0 else None

(* One group (one or more sub-picks sharing one timepoint - see
   [resolve_layer_autonomous]) becomes one [entry]: its notes are every
   sub-pick's notes concatenated, all stamped with the group's single [time];
   [entrydelay] is likewise the group's, never any individual sub-pick's.
   An empty [protos] list is a REST (EMR-3 7.4) - never a genuine resolved
   group (every density mode enforces at least one note), so it's a safe,
   unambiguous signal. This is also exactly what a "rest" [common_harmony_group]
   (see [mk_rest_common_harmony_group]) degenerates to once
   [split_by_layer] converts it, so one branch here covers both paths. *)
let entry_of_group ~variant ~layer ~(seq : Debug_log.entry_seq) time
    (Entrydelay ed) (protos : proto list) : entry =
  let id = { Debug_log.variant; layer; seq } in
  match protos with
  | [] ->
      {
        time;
        entrydelay = ed;
        notes = [];
        instrument = None;
        performance = None;
        dynamic = None;
        duration = Some (Duration ed);
        pitch = None;
        instrument_repeated = false;
        is_rest = true;
        id;
      }
  | _ :: _ ->
      let notes =
        protos
        |> List.concat_map notes_of_proto
        |> List.mapi (fun note_i (n : note) ->
            { n with time; id = { Debug_log.of_entry = id; note = note_i } })
      in
      {
        time;
        entrydelay = ed;
        notes;
        instrument = uniform_value (fun (n : note) -> n.instrument) notes;
        performance = uniform_value (fun (n : note) -> n.performance) notes;
        dynamic = uniform_value (fun (n : note) -> n.dynamic) notes;
        duration = uniform_value (fun (n : note) -> n.duration) notes;
        pitch = uniform_value (fun (n : note) -> n.pitch) notes;
        instrument_repeated =
          List.exists
            (fun (n : note) -> n.diagnostics.instrument_repeated)
            notes;
        is_rest = false;
        id;
      }

(* Pure fold, harmony-independent: sums each group's own (single, shared)
   entry delay into a running absolute time. Split out from the old
   [resolve_times] so union = common-harmony's phase 1 can compute every
   layer's group timestamps *before* HARMONY has run (needed to merge-sort
   across layers - see [resolve_common_harmony_merged]), while s=0/s=2
   still convert straight through to entries via [resolve_times] below. *)
let timed_groups_of (groups : (entrydelay * proto list) list) :
    (float * entrydelay * proto list) list =
  let _, timed =
    List.fold_left
      (fun (t, acc) (ed, protos) ->
        let (Entrydelay edf) = ed in
        (t +. edf, (t, ed, protos) :: acc))
      (0.0, []) groups
  in
  List.rev timed

(* Harmony-dependent: every proto in [timed] must already be fully resolved
   (every field [Some]) - see [notes_of_proto]'s asserts. [seq] (this
   layer's own position in its pre-rest generation order) is assigned here,
   once, via the same [List.mapi] index [Debug_log.entry_seq]'s [Resolved]
   case is built from - it is never recomputed after this, even once REST
   splices rests in around these entries (see [Debug_log.entry_seq]). *)
let entries_of_timed_groups ~variant ~layer
    (timed : (float * entrydelay * proto list) list) : entry list =
  timed
  |> List.mapi (fun seq (t, ed, protos) ->
      entry_of_group ~variant ~layer ~seq:(Debug_log.Resolved seq) t ed protos)

let resolve_times ~variant ~layer (groups : (entrydelay * proto list) list) :
    entry list =
  groups |> timed_groups_of |> entries_of_timed_groups ~variant ~layer

(* ---- REST (EMR-3 7.4) ----
   A standalone post-processing pass, run once per layer after every other
   parameter is already resolved (never part of [hierarchy] - see
   [rest_mode]). The search is a single left-to-right walk over that
   layer's ORIGINAL, no-rest entries: a running [shift] (total silence
   decided-on so far) is added to each original entry's own [time] when
   checking it against the search, but no original entry is ever actually
   moved during the walk. Only [apply_rest_insertions], at the very end,
   builds the real rest-bearing list with every downstream entry's true
   final shifted time - see the plan's own "searched-for against the
   original timeline" design note. *)

(* The minimal shape the search needs - both [entry] and
   [common_harmony_group] adapt down to this, so the algorithm itself
   doesn't depend on either. *)
type rest_target = { time : float; sustain_until : float }

type rest_insertion = {
  before_index : int;
  rest_time : float;
  rest_duration : float;
}

let rest_offset_draw ~d1 ~d2 ~variant_duration =
  (d1 +. Random.float (d2 -. d1)) /. 100.0 *. variant_duration

(* [shift]: total silence inserted so far, applied to every not-yet-
   processed target's own (unmoved) [time]/[sustain_until]. [cursor]: where
   the next ALEA offset is measured from (the end of the just-placed rest,
   in final/shifted time). [running_max]: high-water mark of (shifted)
   [sustain_until] seen so far, carried continuously through the scan - an
   early long-sustaining entry can still cover a much later one, and
   general-entry status is recomputed fresh on every search rather than
   precomputed once (an earlier rest can free a later entry from an
   earlier tone's sustain shadow). [idx] only ever advances (to
   [found_idx + 1], never back to [found_idx]) so this always terminates in
   O(n), even in the degenerate case [d1 = d2 = 0] where the ALEA offset is
   exactly 0 and would otherwise let the same entry satisfy the search
   again forever. *)
let compute_rest_insertions ~variant ~layer ~variant_duration
    ~(rest_mode : rest_mode) ~(targets : rest_target array)
    (dstate : duration sel_state) : rest_insertion list * duration sel_state =
  match rest_mode with
  | RestOff -> ([], dstate)
  | RestBeforeSoundEntry { d1; d2 } | RestBeforeGeneralEntry { d1; d2 } ->
      let is_general =
        match rest_mode with
        | RestBeforeGeneralEntry _ -> true
        | RestBeforeSoundEntry _ -> false
        | RestOff -> assert false
      in
      let n = Array.length targets in
      let rec loop idx shift cursor running_max insertions dstate =
        if idx >= n then (List.rev insertions, dstate)
        else
          let provisional =
            cursor +. rest_offset_draw ~d1 ~d2 ~variant_duration
          in
          let rec scan j running_max =
            if j >= n then None
            else
              let cur_time = targets.(j).time +. shift in
              let cur_sustain = targets.(j).sustain_until +. shift in
              let satisfies =
                cur_time >= provisional
                && ((not is_general) || cur_time > running_max)
              in
              if satisfies then Some (j, running_max)
              else scan (j + 1) (Float.max running_max cur_sustain)
          in
          match scan idx running_max with
          | None -> (List.rev insertions, dstate)
          | Some (found_idx, running_max_before_found) ->
              let ctx : Debug_log.context =
                {
                  variant;
                  layer;
                  seq = RestBefore found_idx;
                  param = Debug_log.PRest;
                }
              in
              let Duration rest_dur, dstate' =
                sel_draw ~ctx ~to_string:duration_to_string dstate
              in
              let rest_time = targets.(found_idx).time +. shift in
              let shift' = shift +. rest_dur in
              let running_max' =
                Float.max running_max_before_found
                  (targets.(found_idx).sustain_until +. shift')
              in
              let insertion =
                {
                  before_index = found_idx;
                  rest_time;
                  rest_duration = rest_dur;
                }
              in
              loop (found_idx + 1) shift' (rest_time +. rest_dur) running_max'
                (insertion :: insertions) dstate'
      in
      loop 0 0.0 0.0 neg_infinity [] dstate

(* Splices [insertions] (strictly increasing [before_index]) into [elems],
   producing the real final list: every element from [elems] carries its
   true shifted time, and each rest sits immediately before the element it
   was found in front of. Generic in ['a] so both adapters below (entry /
   common_harmony_group) can share it. [mk_rest] receives [before_index] so
   the rest it builds can identify itself as [Debug_log.RestBefore
   before_index] - the resolved entry it precedes never gets renumbered by
   this splice (see [Debug_log.entry_seq]), so that reference stays valid
   forever. *)
let apply_rest_insertions ~(shift_time : float -> 'a -> 'a)
    ~(mk_rest : before:int -> time:float -> duration:float -> 'a)
    (insertions : rest_insertion list) (elems : 'a array) : 'a list =
  let n = Array.length elems in
  let rec pass_through i limit shift acc =
    if i >= limit then acc
    else pass_through (i + 1) limit shift (shift_time shift elems.(i) :: acc)
  in
  let rec go idx shift insertions acc =
    match insertions with
    | { before_index; rest_time; rest_duration } :: rest ->
        let acc = pass_through idx before_index shift acc in
        let acc =
          mk_rest ~before:before_index ~time:rest_time ~duration:rest_duration
          :: acc
        in
        go before_index (shift +. rest_duration) rest acc
    | [] -> List.rev (pass_through idx n shift acc)
  in
  go 0 0.0 insertions []

(* ---- Adapter A: [entry list] (for [Union] and [NoUnionPerLayer]) ---- *)

let rest_target_of_entry (e : entry) : rest_target =
  let max_dur =
    e.notes
    |> List.fold_left
         (fun acc (n : note) ->
           let (Duration d) = n.duration in
           Float.max acc d)
         0.0
  in
  { time = e.time; sustain_until = e.time +. max_dur }

(* Every note in [e.notes] was already stamped with its own absolute [time]
   when the entry was first built (see [entry_of_group]) - long before
   REST ever runs - so shifting the entry's own [time] alone would leave
   each note's [time] stale. Both matter downstream: [Midi_export] and the
   note-level score rows read [note.time] directly, never [entry.time]. *)
let shift_entry_time shift (e : entry) : entry =
  {
    e with
    time = e.time +. shift;
    notes =
      e.notes |> List.map (fun (n : note) -> { n with time = n.time +. shift });
  }

let mk_rest_entry ~variant ~layer ~before ~time ~duration : entry =
  {
    time;
    entrydelay = duration;
    notes = [];
    instrument = None;
    performance = None;
    dynamic = None;
    duration = Some (Duration duration);
    pitch = None;
    instrument_repeated = false;
    is_rest = true;
    id = { Debug_log.variant; layer; seq = Debug_log.RestBefore before };
  }

(* [n] (for a possible TENDENCY window) uses this layer's own current entry
   count as a stand-in - the true rest count is only known after running,
   and the manual already treats TENDENCY as not a sensible REST order
   anyway. *)
let insert_rests_entries ~variant ~layer ~variant_duration ~rest_mode ~rest_arr
    ~rest_principle (continuing : continuing_state) (entries : entry list) :
    entry list * continuing_state =
  match rest_mode with
  | RestOff -> (entries, continuing)
  | RestBeforeSoundEntry _ | RestBeforeGeneralEntry _ ->
      let n = List.length entries in
      let rest_state =
        continue_or_restart ~principle:rest_principle ~n
          ~last_arr:continuing.rest_last_arr ~arr:rest_arr continuing.rest_state
      in
      let targets = entries |> List.map rest_target_of_entry |> Array.of_list in
      let insertions, rest_state' =
        compute_rest_insertions ~variant ~layer ~variant_duration ~rest_mode
          ~targets rest_state
      in
      let entries' =
        apply_rest_insertions ~shift_time:shift_entry_time
          ~mk_rest:(mk_rest_entry ~variant ~layer)
          insertions (Array.of_list entries)
      in
      ( entries',
        { continuing with rest_state = rest_state'; rest_last_arr = rest_arr }
      )

(* Builds [states0] (continuing every parameter's own selection cycle across
   layers exactly as before) and dispatches to the right density's resolver,
   returning the still-un-timed [groups] shape. Shared by
   [calculate_layer_hierarchical] (s=0/s=2, timed and converted to entries
   immediately) and [calculate_layer_common_harmony_phase1] (union =
   common-harmony/s=1, timed but harmony deliberately left unresolved - see
   there). *)
(* Reports, once per layer per generic parameter, whether [continue_or_restart]
   is about to continue that parameter's existing draw cycle or start a fresh
   one - a fact about *this layer's own resolution*, not any one entry within
   it (see [Debug_log.event]'s [Continuation]). *)
let continue_or_restart_debug ~variant ~layer ~param ~principle ~n ~last_arr
    ~arr state =
  if !Debug_log.enabled then
    Debug_log.push
      (Debug_log.Continuation
         { variant; layer; param; continued = last_arr = arr });
  continue_or_restart ~principle ~n ~last_arr ~arr state

let resolve_layer_groups ~variant ~layer ~n_events ~variant_n_events ~hierarchy
    ~instr_arr ~instr_principle ~ed_arr ~ed_principle ~perf_arr ~perf_principle
    ~perf_mode ~dyn_arr ~dyn_principle ~dyn_mode ~dur_arr ~dur_principle
    ~dur_relation ~reg_arr ~reg_principle ~reg_mode ~density
    (continuing : continuing_state) :
    (entrydelay * proto list) list * continuing_state =
  let states0 =
    {
      instr_state =
        continue_or_restart_debug ~variant ~layer ~param:Debug_log.PIns
          ~principle:instr_principle ~n:variant_n_events
          ~last_arr:continuing.instr_last_arr ~arr:instr_arr
          continuing.instr_state;
      ed_state =
        continue_or_restart_debug ~variant ~layer ~param:Debug_log.PEnt
          ~principle:ed_principle ~n:variant_n_events
          ~last_arr:continuing.ed_last_arr ~arr:ed_arr continuing.ed_state;
      perf_state =
        continue_or_restart_debug ~variant ~layer ~param:Debug_log.PPer
          ~principle:perf_principle ~n:variant_n_events
          ~last_arr:continuing.perf_last_arr ~arr:perf_arr continuing.perf_state;
      dyn_state =
        continue_or_restart_debug ~variant ~layer ~param:Debug_log.PDyn
          ~principle:dyn_principle ~n:variant_n_events
          ~last_arr:continuing.dyn_last_arr ~arr:dyn_arr continuing.dyn_state;
      dur_state =
        continue_or_restart_debug ~variant ~layer ~param:Debug_log.PDur
          ~principle:dur_principle ~n:variant_n_events
          ~last_arr:continuing.dur_last_arr ~arr:dur_arr continuing.dur_state;
      reg_state =
        continue_or_restart_debug ~variant ~layer ~param:Debug_log.PReg
          ~principle:reg_principle ~n:variant_n_events
          ~last_arr:continuing.reg_last_arr ~arr:reg_arr continuing.reg_state;
      har_state = continuing.har_state;
      (* REST never enters this fold (see [continuing_state.rest_state]) -
         pure pass-through so this record literal stays exhaustive. *)
      rest_state = continuing.rest_state;
      rest_last_arr = continuing.rest_last_arr;
      instr_arr = Array.map value_from_element instr_arr;
      instr_last_arr = instr_arr;
      ed_last_arr = ed_arr;
      perf_last_arr = perf_arr;
      dyn_last_arr = dyn_arr;
      dur_last_arr = dur_arr;
      reg_last_arr = reg_arr;
    }
  in
  match density with
  | InstrumentDensity ->
      resolve_layer_instrument_density ~variant ~layer ~n_events ~hierarchy
        ~perf_mode ~dyn_mode ~dur_relation ~reg_mode states0
  | Autonomous { low; high; selection_principle } ->
      resolve_layer_autonomous ~variant ~layer ~n_events ~hierarchy ~perf_mode
        ~dyn_mode ~dur_relation ~reg_mode ~low ~high ~selection_principle
        states0
  | ChordDensity ->
      resolve_layer_chord_density ~variant ~layer ~n_events ~hierarchy
        ~perf_mode ~dyn_mode ~dur_relation ~reg_mode states0

let calculate_layer_hierarchical ~variant ~layer ~n_events ~variant_n_events
    ~hierarchy ~instr_arr ~instr_principle ~ed_arr ~ed_principle ~perf_arr
    ~perf_principle ~perf_mode ~dyn_arr ~dyn_principle ~dyn_mode ~dur_arr
    ~dur_principle ~dur_relation ~reg_arr ~reg_principle ~reg_mode ~density
    (continuing : continuing_state) =
  let groups, states' =
    resolve_layer_groups ~variant ~layer ~n_events ~variant_n_events ~hierarchy
      ~instr_arr ~instr_principle ~ed_arr ~ed_principle ~perf_arr
      ~perf_principle ~perf_mode ~dyn_arr ~dyn_principle ~dyn_mode ~dur_arr
      ~dur_principle ~dur_relation ~reg_arr ~reg_principle ~reg_mode ~density
      continuing
  in
  (resolve_times ~variant ~layer groups, states')

(* ---- union = common-harmony (EMR-3 6.2's "s=1"): merge every layer's
   entries into one true-chronological timeline and run HARMONY exactly
   once across it, instead of once per layer. ---- *)

(* One entry point (group), tagged for the merge/harmonize/split pipeline
   common-harmony needs. [ch_layer]/[ch_seq] are pure bookkeeping (never a
   musical property) so the final per-layer split doesn't have to rely on
   subtle stable-sort-preserves-input-order reasoning to be obviously
   correct. *)
type common_harmony_group = {
  ch_layer : int;
  ch_seq : int;
  (* this group's position within its own layer's own
                   chronological sequence, before merging *)
  (* [Debug_log.entry_id]'s [seq] this group will carry once
     [split_by_layer] converts it to an [entry] - unlike [ch_seq] (a pure
     sort key, renumbered whenever REST splices a rest into this sequence,
     see [insert_rests_common_harmony_layer]), this is assigned exactly
     once and never touched again: [Resolved n] for a genuinely resolved
     group, [RestBefore n] for a spliced-in rest (see
     [mk_rest_common_harmony_group]). *)
  ch_debug_seq : Debug_log.entry_seq;
  ch_time : float;
  ch_entrydelay : entrydelay;
  ch_protos : proto list; (* harmony NOT yet resolved on any of these *)
}

(* Resolves one layer's hierarchy in full EXCEPT harmony (filtered out of
   [hierarchy] before it ever reaches [resolve_layer_groups] - this is what
   makes every other parameter resolve independently per layer, exactly as
   s=2 does, while leaving HARMONY for the later merged pass). Since [Har]
   never runs here, [continuing.har_state] passes through this layer's own
   fold completely untouched - only instr/ed/perf/dyn/dur/reg state actually
   advance, exactly mirroring how s=2 already threads those six across
   layers. Neither [resolve_layer_instrument_density] nor
   [resolve_layer_autonomous] has any special-cased dependency on [Har]'s
   *presence* in [hierarchy] beyond folding over whatever elements are
   actually there, so passing a [Har]-filtered hierarchy in naturally and
   correctly excludes [Har]'s fold step from every sub-pick. *)
(* [density]'s type - [common_harmony_density], not the general
   [vertical_density] - is what actually keeps CHORD density out of this
   pipeline: there is no [ChordDensity] case to handle here, so nothing
   needs to assert its absence (contrast [resolve_harmony]'s [HarChord]
   arm, which still has to, since [resolve_step] takes the general
   [hierarchy_elem] hierarchy and can't rule Har out of it by its own
   type). CHORD's own harmony resolution ([chord_next]) is a single-pass,
   whole-group mechanism fundamentally incompatible with a deferred,
   cross-layer merge in any case. *)
let calculate_layer_common_harmony_phase1 ~variant ~layer_idx ~n_events
    ~variant_n_events ~hierarchy ~instr_arr ~instr_principle ~ed_arr
    ~ed_principle ~perf_arr ~perf_principle ~perf_mode ~dyn_arr ~dyn_principle
    ~dyn_mode ~dur_arr ~dur_principle ~dur_relation ~reg_arr ~reg_principle
    ~reg_mode ~(density : common_harmony_density) (continuing : continuing_state)
    : common_harmony_group list * continuing_state =
  let hierarchy_no_har = List.filter (fun e -> e <> Har) hierarchy in
  let groups, states' =
    resolve_layer_groups ~variant ~layer:layer_idx ~n_events ~variant_n_events
      ~hierarchy:hierarchy_no_har ~instr_arr ~instr_principle ~ed_arr
      ~ed_principle ~perf_arr ~perf_principle ~perf_mode ~dyn_arr ~dyn_principle
      ~dyn_mode ~dur_arr ~dur_principle ~dur_relation ~reg_arr ~reg_principle
      ~reg_mode ~density:(vertical_density_of_common_harmony_density density)
      continuing
  in
  let tagged =
    timed_groups_of groups
    |> List.mapi (fun seq (t, ed, protos) ->
        {
          ch_layer = layer_idx;
          ch_seq = seq;
          ch_debug_seq = Debug_log.Resolved seq;
          ch_time = t;
          ch_entrydelay = ed;
          ch_protos = protos;
        })
  in
  (tagged, states')

(* Tie-break for simultaneous cross-layer entries (unspecified by the
   manual): sort by [(time, layer index, within-layer sequence number)]
   lexicographically - an explicit, total comparator, not a reliance on
   sort-stability behavior. *)
let compare_common_harmony_groups a b =
  match Float.compare a.ch_time b.ch_time with
  | 0 -> (
      match compare a.ch_layer b.ch_layer with
      | 0 -> compare a.ch_seq b.ch_seq
      | c -> c)
  | c -> c

(* Merges every layer's phase-1 groups into one true-chronological-order
   sequence and runs a SINGLE HARMONY pass across it, so one continuous
   row/interval-matrix walk crosses layer boundaries in true time order
   instead of restarting, or running once per layer. Outer fold walks
   merged groups in true-time order; inner fold walks each group's own
   protos (sub-picks) in their original within-group order - the same
   granularity [resolve_step]'s [Har] case already used (once per proto,
   not once per group). Threading the whole [continuing_state] (not just
   [har_state]) through both folds is harmless: [resolve_harmony] only ever
   changes [har_state], so every other field simply passes through
   untouched. *)
let resolve_common_harmony_merged
    (per_layer_groups : common_harmony_group list list)
    (continuing : continuing_state) :
    common_harmony_group list * continuing_state =
  let merged =
    per_layer_groups |> List.concat |> List.sort compare_common_harmony_groups
  in
  let states', merged_rev =
    List.fold_left
      (fun (states, acc) group ->
        let states', protos_rev =
          List.fold_left
            (fun (states, protos_acc) proto ->
              let states', proto' = resolve_harmony states proto in
              (states', proto' :: protos_acc))
            (states, []) group.ch_protos
        in
        (states', { group with ch_protos = List.rev protos_rev } :: acc))
      (continuing, []) merged
  in
  (List.rev merged_rev, states')

(* Restores each layer's own original declaration order (not the merged/
   sorted order) by re-grouping on [ch_layer] and sorting each bucket by
   [ch_seq], then converts each (now fully harmony-resolved) group to its
   final [entry] - carrying over the [ch_debug_seq] assigned back in phase 1
   (or at rest-splice time) as that entry's permanent id, untouched by
   [ch_seq]'s own renumbering. *)
let split_by_layer ~n_layers ~variant (merged : common_harmony_group list) :
    entry list list =
  let arr = Array.make n_layers [] in
  List.iter (fun g -> arr.(g.ch_layer) <- g :: arr.(g.ch_layer)) merged;
  arr
  |> Array.map (fun groups_rev ->
      groups_rev
      |> List.sort (fun a b -> compare a.ch_seq b.ch_seq)
      |> List.map (fun g ->
          entry_of_group ~variant ~layer:g.ch_layer ~seq:g.ch_debug_seq
            g.ch_time g.ch_entrydelay g.ch_protos))
  |> Array.to_list

(* ---- Adapter B: [common_harmony_group list] (for [NoUnionCommonHarmony],
   run between phase 1 and phase 2 - see [generate_score_hierarchical]). ---- *)

let rest_target_of_common_harmony_group (g : common_harmony_group) : rest_target
    =
  let dur_of_note_value = function
    | Shared (Duration d) -> d
    | PerNote ds ->
        ds |> List.fold_left (fun acc (Duration d) -> Float.max acc d) 0.0
  in
  let max_dur =
    g.ch_protos
    |> List.fold_left
         (fun acc (p : proto) ->
           match p.duration with
           | None -> acc
           | Some dv -> Float.max acc (dur_of_note_value dv))
         0.0
  in
  { time = g.ch_time; sustain_until = g.ch_time +. max_dur }

let shift_ch_group_time shift (g : common_harmony_group) =
  { g with ch_time = g.ch_time +. shift }

let mk_rest_common_harmony_group ~layer_idx ~before ~time ~duration :
    common_harmony_group =
  {
    ch_layer = layer_idx;
    ch_seq = 0 (* renumbered below, see [insert_rests_common_harmony_layer] *);
    ch_debug_seq = Debug_log.RestBefore before;
    ch_time = time;
    ch_entrydelay = Entrydelay duration;
    ch_protos = [];
  }

(* [ch_seq] MUST be renumbered after splicing - it's this layer's own
   position in its pre-merge chronological sequence, consulted by both
   [compare_common_harmony_groups]'s cross-layer tie-break and
   [split_by_layer]'s restore-order sort; a spliced-in rest has no
   "original" position, and every later group's own has shifted. *)
let insert_rests_common_harmony_layer ~variant ~variant_duration ~rest_mode
    ~rest_arr ~rest_principle ~layer_idx (continuing : continuing_state)
    (groups : common_harmony_group list) :
    common_harmony_group list * continuing_state =
  match rest_mode with
  | RestOff -> (groups, continuing)
  | RestBeforeSoundEntry _ | RestBeforeGeneralEntry _ ->
      let n = List.length groups in
      let rest_state =
        continue_or_restart ~principle:rest_principle ~n
          ~last_arr:continuing.rest_last_arr ~arr:rest_arr continuing.rest_state
      in
      let targets =
        groups |> List.map rest_target_of_common_harmony_group |> Array.of_list
      in
      let insertions, rest_state' =
        compute_rest_insertions ~variant ~layer:layer_idx ~variant_duration
          ~rest_mode ~targets rest_state
      in
      let spliced =
        apply_rest_insertions ~shift_time:shift_ch_group_time
          ~mk_rest:(mk_rest_common_harmony_group ~layer_idx)
          insertions (Array.of_list groups)
      in
      let renumbered =
        spliced |> List.mapi (fun seq g -> { g with ch_seq = seq })
      in
      ( renumbered,
        { continuing with rest_state = rest_state'; rest_last_arr = rest_arr }
      )

let zip6 a b c d e f =
  List.map2
    (fun (x, y) (z, (w, (v, u))) -> (x, y, z, w, v, u))
    (List.combine a b)
    (List.combine c (List.combine d (List.combine e f)))

let zip7 a b c d e f g =
  List.map2
    (fun (x, y) (z, (w, (v, (u, t)))) -> (x, y, z, w, v, u, t))
    (List.combine a b)
    (List.combine c (List.combine d (List.combine e (List.combine f g))))

(* TENDENCY's window schedule is scoped to one variant by definition (EMR-3
   p.47: its "number of results" is the total for "the given variant") -
   unlike every other principle, which only resets at a new variant group,
   it resets at the start of every variant. Every other field passes
   through untouched, continuing exactly as it already does across layers. *)
let start_new_variant ~variant ~variant_n_events (continuing : continuing_state)
    =
  let reset_if_tendency ~param state arr =
    match state with
    | STendency (TendencyState { spec; _ }) ->
        Debug_log.emit (fun () ->
            Debug_log.VariantTendencyReset { variant; param });
        STendency
          (tendency_init ~count:variant_n_events
             (Array.map value_from_element arr)
             spec)
    | _ -> state
  in
  {
    continuing with
    instr_state =
      reset_if_tendency ~param:Debug_log.PIns continuing.instr_state
        continuing.instr_last_arr;
    ed_state =
      reset_if_tendency ~param:Debug_log.PEnt continuing.ed_state
        continuing.ed_last_arr;
    perf_state =
      reset_if_tendency ~param:Debug_log.PPer continuing.perf_state
        continuing.perf_last_arr;
    dyn_state =
      reset_if_tendency ~param:Debug_log.PDyn continuing.dyn_state
        continuing.dyn_last_arr;
    dur_state =
      reset_if_tendency ~param:Debug_log.PDur continuing.dur_state
        continuing.dur_last_arr;
    reg_state =
      reset_if_tendency ~param:Debug_log.PReg continuing.reg_state
        continuing.reg_last_arr;
    rest_state =
      reset_if_tendency ~param:Debug_log.PRest continuing.rest_state
        continuing.rest_last_arr;
    (* CHORD's order-of-chords is the one [har_state_t] case with a real
       [sel_state] of its own (ROW/INTERVAL are each their own bespoke
       stream, untouched by any of this) - the table itself never changes
       across layers, so only its [Tendency] window schedule (if that's the
       chosen order) needs the same per-variant reset as every other
       parameter's own [Tendency]-mode field above. *)
    har_state =
      (match continuing.har_state with
      | HarChord hc ->
          HarChord
            {
              hc with
              order_state =
                reset_if_tendency ~param:Debug_log.PChordOrder hc.order_state
                  (elements_of_array hc.table);
            }
      | (HarRow _ | HarInterval _) as other -> other);
  }

let generate_score_hierarchical ~variant ~variant_duration ~instrument_ensemble
    ~instrument_principle ~entry_delay_ensemble ~entry_delay_principle
    ~perf_ensemble ~perf_principle ~perf_mode ~dyn_ensemble ~dyn_principle
    ~dyn_mode ~dur_ensemble ~dur_principle ~dur_relation ~reg_ensemble
    ~reg_principle ~reg_mode ~rest_ensemble ~rest_principle ~rest_mode ~union
    ~hierarchy ~density (continuing : continuing_state) =
  match union with
  | Union ->
      let entr_arr = ensemble_values_union entry_delay_ensemble in
      let instr_arr = ensemble_values_union instrument_ensemble in
      let perf_arr = ensemble_values_union perf_ensemble in
      let dyn_arr = ensemble_values_union dyn_ensemble in
      let dur_arr = ensemble_values_union dur_ensemble in
      let reg_arr = ensemble_values_union reg_ensemble in
      let rest_arr = ensemble_values_union rest_ensemble in
      let n_events =
        calculate_number_of_events variant_duration entry_delay_principle
          entr_arr
      in
      let _ = Printf.printf "estimated events: %d\n" n_events in
      let continuing =
        start_new_variant ~variant ~variant_n_events:n_events continuing
      in
      let entries, continuing' =
        calculate_layer_hierarchical ~variant ~layer:0 ~n_events
          ~variant_n_events:n_events ~hierarchy ~instr_arr
          ~instr_principle:instrument_principle ~ed_arr:entr_arr
          ~ed_principle:entry_delay_principle ~perf_arr ~perf_principle
          ~perf_mode ~dyn_arr ~dyn_principle ~dyn_mode ~dur_arr ~dur_principle
          ~dur_relation ~reg_arr ~reg_principle ~reg_mode ~density continuing
      in
      let entries', continuing'' =
        insert_rests_entries ~variant ~layer:0 ~variant_duration ~rest_mode
          ~rest_arr ~rest_principle continuing' entries
      in
      ([ entries' ], continuing'')
  | NoUnionPerLayer ->
      let instr_arrays = ensemble_values_no_union instrument_ensemble in
      let entr_arrays = ensemble_values_no_union entry_delay_ensemble in
      let perf_arrays = ensemble_values_no_union perf_ensemble in
      let dyn_arrays = ensemble_values_no_union dyn_ensemble in
      let dur_arrays = ensemble_values_no_union dur_ensemble in
      let reg_arrays = ensemble_values_no_union reg_ensemble in
      let rest_arrays = ensemble_values_no_union rest_ensemble in
      let layer_inputs =
        zip7 instr_arrays entr_arrays perf_arrays dyn_arrays dur_arrays
          reg_arrays rest_arrays
      in
      (* TENDENCY's window schedule is sized from the whole variant's total
         event count (EMR-3 p.47: "N = number of time-points in variant"),
         not any one layer's own - computed once, up front, and reused for
         every layer's [Tendency]-tagged field via [continue_or_restart]. *)
      let variant_n_events =
        layer_inputs
        |> List.fold_left
             (fun acc (_, entr_arr, _, _, _, _, _) ->
               acc
               + calculate_number_of_events variant_duration
                   entry_delay_principle entr_arr)
             0
      in
      let continuing =
        start_new_variant ~variant ~variant_n_events continuing
      in
      let continuing', layers =
        layer_inputs
        |> List.mapi (fun i x -> (i, x))
        |> List.fold_left_map
             (fun continuing
                  ( layer,
                    ( instr_arr,
                      entr_arr,
                      perf_arr,
                      dyn_arr,
                      dur_arr,
                      reg_arr,
                      rest_arr ) ) ->
               let n_events =
                 calculate_number_of_events variant_duration
                   entry_delay_principle entr_arr
               in
               let _ = Printf.printf "\nestimated events: %d " n_events in
               let entries, continuing' =
                 calculate_layer_hierarchical ~variant ~layer ~n_events
                   ~variant_n_events ~hierarchy ~instr_arr
                   ~instr_principle:instrument_principle ~ed_arr:entr_arr
                   ~ed_principle:entry_delay_principle ~perf_arr ~perf_principle
                   ~perf_mode ~dyn_arr ~dyn_principle ~dyn_mode ~dur_arr
                   ~dur_principle ~dur_relation ~reg_arr ~reg_principle
                   ~reg_mode ~density continuing
               in
               let entries', continuing'' =
                 insert_rests_entries ~variant ~layer ~variant_duration
                   ~rest_mode ~rest_arr ~rest_principle continuing' entries
               in
               (continuing'', entries'))
             continuing
      in
      (layers, continuing')
  | NoUnionCommonHarmony ->
      let density =
        match common_harmony_density_of_vertical_density density with
        | Some d -> d
        | None ->
            (* structure_formula.ml's own
               [common_harmony_chord_consistency_errors] already rejects
               CHORD density paired with union = common-harmony at
               formula-load time - reaching [None] here would mean that
               validation was bypassed or weakened, not a case this code
               needs to handle gracefully. *)
            assert false
      in
      let instr_arrays = ensemble_values_no_union instrument_ensemble in
      let entr_arrays = ensemble_values_no_union entry_delay_ensemble in
      let perf_arrays = ensemble_values_no_union perf_ensemble in
      let dyn_arrays = ensemble_values_no_union dyn_ensemble in
      let dur_arrays = ensemble_values_no_union dur_ensemble in
      let reg_arrays = ensemble_values_no_union reg_ensemble in
      let rest_arrays = ensemble_values_no_union rest_ensemble in
      let layer_inputs =
        zip6 instr_arrays entr_arrays perf_arrays dyn_arrays dur_arrays
          reg_arrays
      in
      let variant_n_events =
        layer_inputs
        |> List.fold_left
             (fun acc (_, entr_arr, _, _, _, _) ->
               acc
               + calculate_number_of_events variant_duration
                   entry_delay_principle entr_arr)
             0
      in
      let continuing =
        start_new_variant ~variant ~variant_n_events continuing
      in
      (* Phase 1: every layer resolves everything EXCEPT harmony,
         independently - [har_state] passes through this whole fold
         untouched (only instr/ed/perf/dyn/dur/reg state actually advance
         per layer). *)
      let continuing_after_phase1, per_layer_groups =
        layer_inputs
        |> List.mapi (fun i x -> (i, x))
        |> List.fold_left_map
             (fun continuing
                  ( layer_idx,
                    (instr_arr, entr_arr, perf_arr, dyn_arr, dur_arr, reg_arr)
                  ) ->
               let n_events =
                 calculate_number_of_events variant_duration
                   entry_delay_principle entr_arr
               in
               let groups, continuing' =
                 calculate_layer_common_harmony_phase1 ~variant ~layer_idx
                   ~n_events ~variant_n_events ~hierarchy ~instr_arr
                   ~instr_principle:instrument_principle ~ed_arr:entr_arr
                   ~ed_principle:entry_delay_principle ~perf_arr ~perf_principle
                   ~perf_mode ~dyn_arr ~dyn_principle ~dyn_mode ~dur_arr
                   ~dur_principle ~dur_relation ~reg_arr ~reg_principle
                   ~reg_mode ~density continuing
               in
               (continuing', groups))
             continuing
      in
      (* REST (EMR-3 7.4): runs per layer, after phase 1 but before phase 2's
         merge - "REST at last place but one, HARMONY last" under common
         harmony (this is the whole reason REST needs its own pipeline seam
         here rather than living inside phase 1's own per-layer fold). *)
      let continuing_after_rest, per_layer_groups_rested =
        List.combine per_layer_groups rest_arrays
        |> List.mapi (fun i x -> (i, x))
        |> List.fold_left_map
             (fun continuing (layer_idx, (groups, rest_arr)) ->
               let groups', continuing' =
                 insert_rests_common_harmony_layer ~variant ~variant_duration
                   ~rest_mode ~rest_arr ~rest_principle ~layer_idx continuing
                   groups
               in
               (continuing', groups'))
             continuing_after_phase1
      in
      (* Phase 2: merge every layer's groups into one true-chronological
         sequence and run HARMONY exactly once across it. *)
      let merged_with_harmony, continuing_final =
        resolve_common_harmony_merged per_layer_groups_rested
          continuing_after_rest
      in
      (* Phase 3: split back apart into each layer's own original order. *)
      let layers =
        split_by_layer ~n_layers:(List.length layer_inputs) ~variant
          merged_with_harmony
      in
      (layers, continuing_final)

let build_score cfg =
  Random.init cfg.seed;
  let instr_to_string (Instrument { instrument = InstrumentName n; _ }) = n in
  let ed_to_string (Entrydelay f) = Printf.sprintf "%.3f" f in
  let dur_to_string (Duration f) = Printf.sprintf "%.3f" f in
  let reg_to_string = function
    | PercussionRegister -> "percussion"
    | PitchRegister { low; high } ->
        let fmt { octave = Octave o; step = Step s } =
          Printf.sprintf "%d%02d" o s
        in
        Printf.sprintf "%s-%s" (fmt low) (fmt high)
  in
  (* EMR-3 p.130-132 (Fig. 10-2): an uncombined parameter's group selection
     "only occurs 'per layer'" - one fresh group per layer, not one group for
     the whole variant. With union, there is only ever one resulting layer,
     so the two coincide. *)
  let uncombined_group_count =
    match cfg.union with
    | Union -> 1
    | NoUnionPerLayer | NoUnionCommonHarmony -> cfg.number_of_instrument_groups
  in
  (* An uncombined parameter's ensemble is drawn *once*, for the whole run,
     requesting [cfg.n_variants] times as many groups as one variant needs -
     not once per variant - since [construct_ensemble] starts a fresh
     selection cycle every time it's called (EMR-3 6.2/9.8: "the selection
     cycle runs through all variants of a variant group"; calling it again
     per variant would restart exactly the cycle this is meant to keep
     continuous). [slice_ensemble] then splits that one continuous draw back
     into each variant's own share. A combined parameter has no cycle of its
     own to protect this way - it's a pure function of however many groups
     instrument picked for that variant - so it's simply reconstructed fresh
     per variant from that variant's own instrument slice, below. *)
  let slice_ensemble ~groups_per_variant ensemble =
    match ensemble with
    | SingleGroup g -> Array.init cfg.n_variants (fun _ -> SingleGroup g)
    | Ensemble groups ->
        chunk (repeat_n groups_per_variant cfg.n_variants) (List.to_seq groups)
        |> Seq.map (fun s -> Ensemble (List.of_seq s))
        |> Array.of_seq
  in
  let instr_ensembles =
    construct_ensemble ~label:"instrument" ~to_string:instr_to_string
      cfg.instr_list cfg.instr_table EnsembleGroupSeries
      (cfg.n_variants * cfg.number_of_instrument_groups)
    |> slice_ensemble ~groups_per_variant:cfg.number_of_instrument_groups
  in
  (* Returns a per-variant ensemble getter for one schematic parameter,
     unifying the two cases above behind one interface. *)
  let ensemble_for ~label ~to_string parlist table combination =
    match combination with
    | Combination ->
        fun v ->
          construct_ensemble_combination ~label ~to_string parlist table
            instr_ensembles.(v)
    | NoCombination sel ->
        let sliced =
          construct_ensemble ~label ~to_string parlist table sel
            (cfg.n_variants * uncombined_group_count)
          |> slice_ensemble ~groups_per_variant:uncombined_group_count
        in
        fun v -> sliced.(v)
  in
  let ed_ensemble_for =
    ensemble_for ~label:"entrydelay" ~to_string:ed_to_string cfg.ed_list
      cfg.ed_table cfg.entrydelay_combination
  in
  let perf_ensemble_for =
    ensemble_for ~label:"performance" ~to_string:Performance.to_string
      cfg.perf_list cfg.performance_table cfg.performance_combination
  in
  let dyn_ensemble_for =
    ensemble_for ~label:"dynamics" ~to_string:Dynamic.to_string cfg.dyn_list
      cfg.dynamics_table cfg.dynamics_combination
  in
  let dur_ensemble_for =
    ensemble_for ~label:"duration" ~to_string:dur_to_string cfg.dur_list
      cfg.dur_table cfg.duration_combination
  in
  let reg_ensemble_for =
    ensemble_for ~label:"register" ~to_string:reg_to_string cfg.reg_list
      cfg.register_table cfg.register_combination
  in
  (* [ensemble_for]'s [NoCombination] branch calls [construct_ensemble]
     EAGERLY (not deferred per-variant). When REST is off, [rest_list]/
     [rest_table] are deliberately empty (see [Structure_formula.Parse]'s
     REST parsing) - calling [construct_ensemble] on a zero-row table to
     select [cfg.n_variants * uncombined_group_count] (always >= 1) groups
     from it would very likely crash, even though the result is never read.
     This guard sidesteps [construct_ensemble] entirely in that case -
     [ensemble_values_no_union] still needs one (empty) group per layer,
     matching [uncombined_group_count], so every zip/combine against the
     other per-layer arrays stays aligned regardless of REST's own mode. *)
  let rest_ensemble_for =
    match cfg.rest_mode with
    | RestOff ->
        fun _ ->
          Ensemble
            (List.init uncombined_group_count (fun i ->
                 IndexedEnsembleGroup { index = i; group = EnsembleGroup [||] }))
    | RestBeforeSoundEntry _ | RestBeforeGeneralEntry _ ->
        ensemble_for ~label:"rest" ~to_string:dur_to_string cfg.rest_list
          cfg.rest_table cfg.rest_combination
  in
  let continuing0 = initial_continuing_state ~tr:cfg.tr cfg.harmony in
  (* One [generate_score_hierarchical] call per variant, [continuing]
     threaded from the last variant into the next exactly as it already
     threads from layer to layer within one - the fresh start EMR-3 grants
     only belongs to a genuinely new variant *group* (a new seed), never to
     a variant within this one run. *)
  let (_ : continuing_state), variants =
    List.fold_left_map
      (fun continuing v ->
        let layers, continuing' =
          generate_score_hierarchical ~variant:v
            ~variant_duration:cfg.variant_duration
            ~instrument_ensemble:instr_ensembles.(v)
            ~instrument_principle:cfg.instrument_principle
            ~entry_delay_ensemble:(ed_ensemble_for v)
            ~entry_delay_principle:cfg.entrydelay_principle
            ~perf_ensemble:(perf_ensemble_for v)
            ~perf_principle:cfg.performance_principle
            ~perf_mode:cfg.performance_mode ~dyn_ensemble:(dyn_ensemble_for v)
            ~dyn_principle:cfg.dynamics_principle ~dyn_mode:cfg.dynamics_mode
            ~dur_ensemble:(dur_ensemble_for v)
            ~dur_principle:cfg.duration_principle
            ~dur_relation:cfg.duration_relation_mode
            ~reg_ensemble:(reg_ensemble_for v)
            ~reg_principle:cfg.register_principle ~reg_mode:cfg.register_mode
            ~rest_ensemble:(rest_ensemble_for v)
            ~rest_principle:cfg.rest_principle ~rest_mode:cfg.rest_mode
            ~union:cfg.union ~hierarchy:cfg.hierarchy ~density:cfg.density
            continuing
        in
        (continuing', layers))
      continuing0
      (List.init cfg.n_variants (fun v -> v))
  in
  variants

(* How many notes, across every variant/layer generated this run, hit
   HARMONY's INTERVAL principle "INTERVAL RESTRICTIONS TOO STRICT" fallback
   ([harmony_matrix_ok = false] - see [interval_next]/[note_problems]).
   Always 0 for ROW/CHORD, which never set this flag false. Surfaced as a
   run-level diagnostic (`--json`'s [render_json] in bin/main_sexp.ml) so the
   composer sees it without reading the generated score's inline "#
   IMPOSSIBLE" comments - a fact about *this run*, not about the formula's
   static shape, so it necessarily comes from an actual generation rather
   than [Structure_formula]'s own validation. *)
let count_interval_restrictions_too_strict (variants : entry list list list) =
  variants |> List.concat |> List.concat
  |> List.concat_map (fun (e : entry) -> e.notes)
  |> List.filter (fun (n : note) -> not n.diagnostics.harmony_matrix_ok)
  |> List.length

