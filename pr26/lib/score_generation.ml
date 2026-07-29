open Parameters
open Structure_formula
open Selection
open Tools

(* A resolved note-within-a-chord: fully-specified, no options. Entry delay
   is deliberately absent - it is a property of the [entry] (the shared
   timepoint/chord a note belongs to), never of an individual note. *)
type note = {
  time : float;
  instrument : instr;
  performance : Performance.t;
  dynamic : Dynamic.t;
  duration : duration;
  (* [false] iff this duration was an [Impossible] fallback: no candidate
     actually satisfied the duration/entry-delay relation. *)
  duration_ok : bool;
  pitch : pitch;
  (* [false] iff [Reg]/[Har]'s resolved values didn't actually agree (a
     percussion register paired with a real step, or a register the step
     didn't fit in) - see [resolve_pitch]. *)
  pitch_ok : bool;
  (* [true] iff this note's instrument had already been picked earlier within
     the same autonomous-density chord - i.e. there weren't enough distinct
     instruments to "score" the chord without reusing one (EMR-3 8.16). *)
  instrument_repeated : bool;
}

(* Entry is one timepoint:
  In Pr2, you can have multiple notes starting at one entry point / time slot in the score.
  A bit analogous to a "chord", although for each parameter, you can control if it should also use the same value for all
  "voices" within the chord ot not.
  This is why some parameters are optional in entry, if they are to be decided on a note level, they don't have a value at the entry level.
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
  (* see [note.instrument_repeated] - true if any note in this entry is. *)
  instrument_repeated : bool;
}

(* Extract all elements from any ensemble as a flat array. Each element
   keeps the LIST index it was resolved from (not just its value) so that
   RATIO can weight by original LIST index rather than by ensemble
   position - see [sel_init]'s [Ratio] branch. *)
let ensemble_values_union ensemble =
  match ensemble with
  | Ensemble groups ->
      groups |> List.map elements_from_indexed_ensemble |> Array.concat
  | SingleGroup elm -> elm |> elements_from_indexed_ensemble

let ensemble_values_no_union ensemble =
  match ensemble with
  | Ensemble groups -> groups |> List.map elements_from_indexed_ensemble
  | SingleGroup g -> [ g |> elements_from_indexed_ensemble ]

(* ---- Pure stateful selection principles state  ---- *)
(* [sel_state] wraps the per-principle state. All draws are pure:
   [sel_draw st] returns [(value, next_st)] without any mutation.
   The caller threads [next_st] forward explicitly. *)
type 'a sel_state =
  | SAlea of 'a alea_state
  | SSeries of 'a series_state
  | SRatio of 'a ratio_state
  | SGroup of 'a group_state
  | STendency of 'a tendency_state
  | SSequence of 'a sequence_state

(* [arr] carries each element's original LIST index alongside its value, so
   that [Ratio]'s weights (declared per LIST index, see [ratio_weight_of])
   can be applied to whatever actually made it into this ensemble - callers
   with no LIST/ENSEMBLE stage of their own (e.g. the synthetic density
   range) just wrap their plain array with [elements_of_array] first. *)
let sel_init (principle : selection_principle) (n : int)
    (arr : 'a element array) : 'a sel_state =
  let values = Array.map value_from_element arr in
  match principle with
  | Alea -> SAlea (alea_init values)
  | Series -> SSeries (series_init values)
  | Ratio weighted ->
      let weight_of = ratio_weight_of weighted in
      let pool =
        arr |> Array.to_list
        |> List.map (fun { index; value } -> (value, weight_of index))
      in
      SRatio (ratio_init pool)
  | Group gs -> SGroup (group_init values gs)
  | Tendency spec -> STendency (tendency_init ~count:n values spec)
  | Sequence indices ->
      SSequence (sequence_init (List.map (fun i -> values.(i)) indices))

let sel_draw : 'a sel_state -> 'a * 'a sel_state = function
  | SAlea s ->
      let v, s' = alea_draw s in
      (get_value v, SAlea s')
  | SSeries s ->
      let v, s' = series_draw s in
      (get_value v, SSeries s')
  | SRatio s ->
      let v, s' = ratio_draw s in
      (get_value v, SRatio s')
  | SGroup s ->
      let v, s' = group_draw s in
      (get_value v, SGroup s')
  | STendency s ->
      let v, s' = tendency_draw s in
      (get_value v, STendency s')
  | SSequence s ->
      let v, s' = sequence_draw s in
      (get_value v, SSequence s')

(* Tagged variant of a predicate-conditioned draw: callers that need to know
   whether the hierarchy's constraint could actually be satisfied (e.g. to
   flag an "impossible" duration in the score) can inspect the
   [selection_result] tag; callers that don't care just [get_value] it. *)
let sel_draw_pred_tagged (p : 'a -> bool) :
    'a sel_state -> 'a selection_result * 'a sel_state = function
  | SAlea s ->
      let v, s' = alea_draw_predicate p s in
      (v, SAlea s')
  | SSeries s ->
      let v, s' = series_draw_predicate p s in
      (v, SSeries s')
  | SRatio s ->
      let v, s' = ratio_draw_predicate p s in
      (v, SRatio s')
  | SGroup s ->
      let v, s' = group_draw_predicate p s in
      (v, SGroup s')
  | STendency s ->
      (* Sample from the predicate-filtered array within the current window,
         then advance the state to the next window position. *)
      let (TendencyState { arr; lo; hi; _ }) = s in
      let filtered = arr |> Array.to_list |> List.filter p |> Array.of_list in
      let v =
        if Array.length filtered = 0 then Impossible (tendency_sample arr lo hi)
        else Value (tendency_sample filtered lo hi)
      in
      let _, s' = tendency_draw s in
      (v, STendency s')
  | SSequence s ->
      (* Sequence has no predicate mechanism; advance freely. *)
      let v, s' = sequence_draw s in
      (v, SSequence s')

let sel_draw_pred (p : 'a -> bool) : 'a sel_state -> 'a * 'a sel_state =
 fun state ->
  let v, state' = sel_draw_pred_tagged p state in
  (get_value v, state')

(** Draw [n] values from [arr] using [principle], threading a single state
    through all draws (so e.g. [Series]/[Sequence] exhaust their options before
    repeating). *)
let sel_draw_n n principle arr =
  let _, values =
    List.init n id
    |> List.fold_left
         (fun (st, acc) _ ->
           let v, st' = sel_draw st in
           (st', v :: acc))
         (sel_init principle n arr, [])
  in
  List.rev values

(* Sample a value at the current position without consuming it. For
   [Tendency] this samples within the current window without moving it; all
   other principles thread one shared sequence through every draw regardless
   of time point, so sampling is the same as drawing. *)
let sel_sample : 'a sel_state -> 'a * 'a sel_state = function
  | STendency (TendencyState { arr; lo; hi; _ } as s) ->
      (tendency_sample arr lo hi, STendency s)
  | st -> sel_draw st

(* Move a [Tendency] state on to its next window, marking the end of a time
   point. Other principles already advance on every [sel_sample], so this is
   a no-op for them. *)
let sel_advance_window : 'a sel_state -> 'a sel_state = function
  | STendency s ->
      let _, s' = tendency_draw s in
      STendency s'
  | st -> st

(* Same as [sel_draw_pred], but for [Tendency] this samples within the
   current window without moving it (mirrors how [sel_sample] relates to
   [sel_draw]). Used to draw several values within one timepoint (e.g. several
   entries sharing an autonomous-density timepoint, or several notes within
   one entry) while only moving each tendency mask's window once per
   timepoint, via a single later [sel_advance_window] call. *)
let sel_sample_pred_tagged (p : 'a -> bool) :
    'a sel_state -> 'a selection_result * 'a sel_state = function
  | STendency (TendencyState { arr; lo; hi; _ } as s) ->
      let filtered = arr |> Array.to_list |> List.filter p |> Array.of_list in
      let v =
        if Array.length filtered = 0 then Impossible (tendency_sample arr lo hi)
        else Value (tendency_sample filtered lo hi)
      in
      (v, STendency s)
  | st -> sel_draw_pred_tagged p st

let sel_sample_pred (p : 'a -> bool) : 'a sel_state -> 'a * 'a sel_state =
 fun state ->
  let v, state' = sel_sample_pred_tagged p state in
  (get_value v, state')

let result_ok = function Value _ -> true | Impossible _ -> false

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

(* In-progress entry while the hierarchy fold (iteration/loop) runs: everything starts [None]
   and gets filled in hierarchy order. Values of "lower" parameters may be limited by already provided ones.
   [nr_of_notes] is filled as soon as
   [Ins] runs (chordsize is a property of the picked instrument). *)
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
     try cap without finding a value agreeing with [Reg] - see there. *)
  harmony_ok : bool note_value option;
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
  }

(* States threaded through the hierarchy fold — one per parameter hierarchy
   controls. [instr_arr] is kept here so a step can constrain itself to
   values achievable by at least one instrument in this group, even before
   [Ins] has run. *)
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
  (* Not a [sel_state]: ROW is its own bespoke, order-preserving stream
     (EMR-3 8.2), never an Alea/Series/Tendency draw - see [row_stream]. *)
  har_state : row_value Seq.t;
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
let initial_continuing_state ~tr ~transposition row : continuing_state =
  {
    instr_state = SAlea (alea_init [||]);
    ed_state = SAlea (alea_init [||]);
    perf_state = SAlea (alea_init [||]);
    dyn_state = SAlea (alea_init [||]);
    dur_state = SAlea (alea_init [||]);
    reg_state = SAlea (alea_init [||]);
    har_state = row_stream ~tr ~transposition row;
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
let resolve_note_param_tagged mode n_notes pred state =
  match mode with
  | PerChord ->
      let v, state' = sel_sample_pred_tagged pred state in
      let ok = result_ok v in
      (Shared (get_value v), Shared ok, state')
  | PerNote ->
      let n = Option.value n_notes ~default:1 in
      let vs, oks, state' =
        List.init n (fun _ -> ())
        |> List.fold_left
             (fun (acc, oks_acc, st) () ->
               let v, st' = sel_sample_pred_tagged pred st in
               let ok = result_ok v in
               (get_value v :: acc, ok :: oks_acc, st'))
             ([], [], state)
      in
      (PerNote (List.rev vs), PerNote (List.rev oks), state')

let resolve_note_param mode n_notes pred state =
  let values, _oks, state' =
    resolve_note_param_tagged mode n_notes pred state
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
let ins_pred_from proto =
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
  fun i -> from_perf i && from_dyn i && from_dur i && from_reg i

(* [Per]/[Dyn]'s predicate: restrict to modes the (already- or not-yet-known)
   instrument can play, exactly mirroring [Ins]'s own conditioning above. *)
let mode_pred_from_instrument ~instr_arr ~mem proto_instrument instr_modes =
  match proto_instrument with
  | Some i -> fun v -> mem v (instr_modes i)
  | None -> fun v -> Array.exists (fun i -> mem v (instr_modes i)) instr_arr

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
  match (dur_relation, proto.entrydelay) with
  | DurShorterThanEntry _, Some (Entrydelay ed) ->
      fun (Duration d as dv) -> range_pred dv && d <= ed
  | _ -> range_pred

let duration_note_mode = function
  | DurIndependent m -> m
  | DurEqualsEntry -> PerChord
  | DurShorterThanEntry m -> m

(* Entry delay's own conditioning: unconstrained, unless DUR-ENTRY requires
   it to follow duration (which must then already be known). *)
let ed_pred_from proto dur_relation =
  match (dur_relation, proto.duration) with
  | DurShorterThanEntry _, Some (Shared (Duration d)) ->
      fun (Entrydelay ed) -> ed >= d
  | DurShorterThanEntry _, Some (PerNote ds) ->
      let max_d =
        ds |> List.map (fun (Duration d) -> d) |> List.fold_left Float.max 0.0
      in
      fun (Entrydelay ed) -> ed >= max_d
  | _ -> Fun.const true

let register_is_percussion = function
  | PercussionRegister -> true
  | PitchRegister _ -> false

let row_value_is_percussion = function
  | RowPercussion -> true
  | Tone _ -> false

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
  fun r -> instr_pred r && harmony_pred r

(* [Har]'s predicate: percussion-agreement with the already-resolved
   [Reg] (when [Reg] ran first) - see [reg_pred_from] above for the
   PerNote/"must satisfy all" caveat, which applies symmetrically here. No
   direct dependence on [Ins]: relative pitch doesn't depend on which
   instrument plays it, only REGISTER mediates that (EMR-3 §7.1). *)
let har_pred_from proto =
  match proto.register with
  | None -> Fun.const true
  | Some (Shared r) ->
      fun h -> row_value_is_percussion h = register_is_percussion r
  | Some (PerNote rs) ->
      fun h ->
        List.for_all
          (fun r -> row_value_is_percussion h = register_is_percussion r)
          rs

(* One hierarchy element's worth of work for one entry. This is the single
   place that knows how [Ins]/[Ent]/[Dur]/[Per]/[Dyn] each condition on, or
   get conditioned by, one another - both density modes below just fold this
   over the composer's [hierarchy] list once per entry. *)
let resolve_step ~perf_mode ~dyn_mode ~dur_relation ~reg_mode
    (states, proto) elem =
  match elem with
  | Ins ->
      let v, instr_state' =
        sel_sample_pred (ins_pred_from proto) states.instr_state
      in
      let (Instrument { chordsize = Chordsize { minsize; maxsize }; _ }) = v in
      let n =
        if minsize = maxsize then minsize
        else Random.int (maxsize - minsize + 1) + minsize
      in
      ( { states with instr_state = instr_state' },
        { proto with instrument = Some v; nr_of_notes = Some n } )
  | Ent -> (
      match (dur_relation, proto.duration) with
      | DurEqualsEntry, Some (Shared (Duration d)) ->
          (states, { proto with entrydelay = Some (Entrydelay d) })
      | DurEqualsEntry, None ->
          (* [Dur] hasn't resolved yet, so it will just copy this entry delay
             through verbatim (below) - constrain the draw itself to what the
             instrument can sustain as a duration, rather than drawing freely
             and clamping afterwards, which would silently break the
             "duration = entry delay" invariant this mode promises. *)
          let pred (Entrydelay ed) =
            dur_pred_from ~instr_arr:states.instr_arr proto dur_relation
              (Duration ed)
          in
          let v, ed_state' = sel_sample_pred_tagged pred states.ed_state in
          let ok = result_ok v in
          ( { states with ed_state = ed_state' },
            {
              proto with
              entrydelay = Some (get_value v);
              duration_ok = Some (Shared ok);
            } )
      | _ ->
          let pred = ed_pred_from proto dur_relation in
          let v, ed_state' = sel_sample_pred pred states.ed_state in
          ( { states with ed_state = ed_state' },
            { proto with entrydelay = Some v } ))
  | Dur -> (
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
          let pred =
            dur_pred_from ~instr_arr:states.instr_arr proto dur_relation
          in
          let v, oks, dur_state' =
            resolve_note_param_tagged mode proto.nr_of_notes pred
              states.dur_state
          in
          ( { states with dur_state = dur_state' },
            { proto with duration = Some v; duration_ok = Some oks } ))
  | Per ->
      let pred =
        mode_pred_from_instrument ~instr_arr:states.instr_arr
          ~mem:Performance_modes.mem proto.instrument
          (fun (Instrument { performance; _ }) -> performance)
      in
      let v, perf_state' =
        resolve_note_param perf_mode proto.nr_of_notes pred states.perf_state
      in
      ( { states with perf_state = perf_state' },
        { proto with performance = Some v } )
  | Dyn ->
      let pred =
        mode_pred_from_instrument ~instr_arr:states.instr_arr
          ~mem:Dynamic_modes.mem proto.instrument
          (fun (Instrument { dynamics; _ }) -> dynamics)
      in
      let v, dyn_state' =
        resolve_note_param dyn_mode proto.nr_of_notes pred states.dyn_state
      in
      ({ states with dyn_state = dyn_state' }, { proto with dynamic = Some v })
  | Reg ->
      let pred = reg_pred_from ~instr_arr:states.instr_arr proto in
      let v, oks, reg_state' =
        resolve_note_param_tagged reg_mode proto.nr_of_notes pred
          states.reg_state
      in
      ( { states with reg_state = reg_state' },
        { proto with register = Some v; register_ok = Some oks } )
  | Har ->
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
        (states, { proto with harmony = Some v; harmony_ok = Some oks })
      else
        let pred = har_pred_from proto in
        let n = Option.value proto.nr_of_notes ~default:1 in
        (* [row_stream] is infinite (it keeps re-transposing once the row is
           used up), but every pass preserves which entries are
           [RowPercussion] vs [Tone] - a composer-written row with no [Tone]
           at all (or none at all matching a fixed non-percussion register)
           would make [pred] unsatisfiable forever. Cap the search instead of
           risking an infinite loop; beyond the cap, accept the next value
           anyway and flag it not-ok, mirroring EMR-3's own "wrong pitch...
           provided with a comment" fallback. *)
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
        (* EMR-3's ROW (entry 19) has no "per chord" call number: every note
           in a chord always gets its own successive row value, ignoring the
           entry-point boundary entirely. (A genuine shared-per-chord harmony
           is a distinct, not-yet-implemented CHORD principle, not a mode of
           ROW.) *)
        let v, oks, har_state' =
          let vs, oks, st' =
            List.init n (fun _ -> ())
            |> List.fold_left
                 (fun (acc, oks_acc, st) () ->
                   let hd, tl, ok = draw_one st in
                   (hd :: acc, ok :: oks_acc, tl))
                 ([], [], states.har_state)
          in
          (PerNote (List.rev vs), PerNote (List.rev oks), st')
        in
        ( { states with har_state = har_state' },
          { proto with harmony = Some v; harmony_ok = Some oks } )

let resolve_entry ?(start = empty_proto) ~hierarchy ~perf_mode ~dyn_mode
    ~dur_relation ~reg_mode states =
  List.fold_left
    (resolve_step ~perf_mode ~dyn_mode ~dur_relation ~reg_mode)
    (states, start) hierarchy

(** With [InstrumentDensity], every entry is its own timepoint - one instrument,
    one already-resolved entry delay. Each is wrapped as a singleton group so
    step 2 can treat both density modes uniformly. *)
let resolve_layer_instrument_density ~n_events ~hierarchy ~perf_mode ~dyn_mode
    ~dur_relation ~reg_mode states0 =
  let final_states, groups =
    List.init n_events (fun _ -> ())
    |> List.fold_left
         (fun (states, acc) () ->
           let states', proto =
             resolve_entry ~hierarchy ~perf_mode ~dyn_mode ~dur_relation
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

(* Whole-chord ([PerChord]) values already fixed before a sub-pick's own
   hierarchy fold runs, for whichever of performance/dynamics/register the
   composer's hierarchy puts before [Ins] (see [resolve_layer_autonomous]).
   Duration is handled separately (inline in [fill_group]) since its own
   extraction also depends on entry delay's timing, not just [Ins]'s -
   [register]/[duration] additionally carry their "_ok" flag alongside the
   value, since (unlike performance/dynamic) [proto] tracks whether each was
   an [Impossible] fallback. *)
type chord_seeds = {
  cs_perf : Performance.t note_value option;
  cs_dyn : Dynamic.t note_value option;
  cs_reg : (register note_value * bool note_value) option;
  cs_dur : (duration note_value * bool note_value) option;
}

let no_chord_seeds = { cs_perf = None; cs_dyn = None; cs_reg = None; cs_dur = None }

(** With [Autonomous] density, each timepoint samples a target density and keeps
    resolving sub-picks (each independently picking its own instrument,
    conditioned the same way as any other) until the target is reached. If the
    last pick's chordsize would overshoot the target, its extra voices are cut -
    [nr_of_notes] is capped down to however many are still needed, so the
    group's total lands exactly on the target.

    Unlike [InstrumentDensity], a timepoint here may need several sub-picks to
    "score" the chord (EMR-3 8.16), and several of the chord-wide parameters -
    entry delay always, and performance/dynamics/duration/register whenever
    their own mode is [PerChord] - must each end up as exactly *one* shared
    value for the whole chord, not one independent draw per sub-pick. Each is
    therefore excluded from every sub-pick's own hierarchy fold
    ([subpick_hierarchy]) and resolved once per group instead - via
    [fill_subpicks]'s [~seed]/[~seeds] (values already fixed before the loop,
    seeded into every sub-pick's [start] proto so its own still-in-the-fold
    steps condition on them exactly as they would for a single sub-pick - e.g.
    [Ins]'s [ins_pred_from] already reads every one of these fields) or by
    aggregating over the finished group afterward (values that depend on
    something only known *after* the loop, such as which instruments actually
    got picked - constrained to agree with all of them, mirroring the
    conservative "must satisfy every one" choice [resolve_step] already makes
    for a single proto's own per-note values).

    Entry delay's own before/after split is the simplest case, and the
    template every other extraction below follows: it's governed by wherever
    the composer put [Ent] relative to [Dur] ([ent_before_dur]), using the
    exact same predicates [resolve_step] already uses for a single sub-pick
    ([dur_pred_from]/[ed_pred_from]) - just fed a value that's fixed for the
    whole group instead of one proto:
    - [Ent] before [Dur]: the group's entry delay is drawn once, up front, and
      every sub-pick's [Dur] step conditions on it exactly as it would if [Ent]
      had run first for that one sub-pick (seeded via [resolve_entry]'s
      [~start], never drawn again).
    - [Dur] before [Ent]: every sub-pick's [Dur] resolves unconstrained (no
      entry delay exists yet), and the group's entry delay is drawn once *after*
      the loop, either unconstrained ([DurIndependent]) or bounded by the
      longest duration seen anywhere in the group ([DurShorterThanEntry] -
      generalizing [ed_pred_from]'s own per-proto max-over-per-note-values check
      to a max over the whole group). [DurEqualsEntry] is the one relation where
      this ordering still settles the shared value mid-loop: the first
      sub-pick's freely-drawn duration *becomes* the group's entry delay, and
      every later sub-pick is then forced to copy it (mirroring the original
      single-sub-pick "[Dur] before [Ent]" case, just decided once for the whole
      chord instead of once per sub-pick) - so [DurEqualsEntry] (always
      [PerChord] already, by definition) needs no further extraction below.

    [Per]/[Dyn] each depend on nothing but the instrument, so their own
    extraction ([fill_group_with_note_modes]) is a direct copy of the same
    before/after-[Ins] idea. [Reg] depends on the instrument *and* on harmony -
    but harmony is always per-note (never extracted, EMR-3 entry 19 has no
    "per chord" reading) and [Ins] always precedes [Har] (enforced at
    formula-load time), so by the time a sub-pick's own fold reaches [Har] (if
    it's still in [subpick_hierarchy]), [Ins] has necessarily already run for
    that sub-pick too - meaning "before or after [Ins]" is still the only
    question that matters for [Reg]'s own extraction: either nothing has run
    for anyone yet (seed forward, unconstrained by harmony, letting every
    sub-pick's own harmony draw agree with the now-fixed register instead), or
    the *entire* group - including every note's harmony - is already known
    (aggregate over both). [Dur] (when [DurIndependent]/[DurShorterThanEntry]
    and [PerChord]) has the same [Ins] dependency as [Per]/[Dyn], plus entry
    delay's own dependency - so its extraction combines both splits, and stays
    inline in [fill_group] rather than joining [fill_group_with_note_modes],
    since it needs branch-local knowledge of whether entry delay is already
    fixed. *)
let resolve_layer_autonomous ~n_events ~hierarchy ~perf_mode ~dyn_mode
    ~dur_relation ~reg_mode ~low ~high ~selection_principle states0 =
  let dens_arr =
    Array.init (high - low + 1) (fun i -> low + i) |> elements_of_array
  in
  let index_of x =
    let rec go i = function
      | [] ->
          assert false
          (* hierarchy is always a permutation of all 5 elems - see mk_hierarchy *)
      | y :: rest -> if y = x then i else go (i + 1) rest
    in
    go 0 hierarchy
  in
  let ent_before_dur = index_of Ent < index_of Dur in
  let dur_note_mode = duration_note_mode dur_relation in
  (* [DurEqualsEntry] is always [PerChord] already and already fully handled
     below (the drawn value becomes the group's one entry delay directly) -
     nothing further to extract for it. *)
  let dur_extracted = dur_relation <> DurEqualsEntry && dur_note_mode = PerChord in
  let perf_extracted = perf_mode = PerChord in
  let dyn_extracted = dyn_mode = PerChord in
  let reg_extracted = reg_mode = PerChord in
  let perf_before_ins = index_of Per < index_of Ins in
  let dyn_before_ins = index_of Dyn < index_of Ins in
  let reg_before_ins = index_of Reg < index_of Ins in
  let dur_before_ins = index_of Dur < index_of Ins in
  let subpick_hierarchy =
    hierarchy
    |> List.filter (fun e -> e <> Ent)
    |> List.filter (fun e -> not (e = Per && perf_extracted))
    |> List.filter (fun e -> not (e = Dyn && dyn_extracted))
    |> List.filter (fun e -> not (e = Reg && reg_extracted))
    |> List.filter (fun e -> not (e = Dur && dur_extracted))
  in
  let resolve_subpick ?seed_entrydelay ~seeds states =
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
      }
    in
    resolve_entry ~start ~hierarchy:subpick_hierarchy ~perf_mode ~dyn_mode
      ~dur_relation ~reg_mode states
  in
  (* Every sub-pick's own instrument, once the group is fully resolved -
     needed by whichever of performance/dynamics/register/duration must
     aggregate over the whole group *after* the loop (see below). *)
  let instruments_of group =
    List.map
      (fun p -> match p.instrument with Some i -> i | None -> assert false)
      group
  in
  let max_duration_of proto =
    match proto.duration with
    | Some (Shared (Duration d)) -> d
    | Some (PerNote ds) ->
        ds |> List.map (fun (Duration d) -> d) |> List.fold_left Float.max 0.0
    | None -> 0.0
  in
  let force_not_ok = function
    | Shared _ -> Shared false
    | PerNote xs -> PerNote (List.map (fun _ -> false) xs)
  in
  (* Overrides [duration_ok] group-wide: used when the group's one shared
     entry delay itself turned out [Impossible], a chord-level fact that
     can't be pinned on any single sub-pick's own (otherwise-fine) draw. *)
  let mark_group_ok ok proto =
    if ok then proto
    else { proto with duration_ok = Option.map force_not_ok proto.duration_ok }
  in
  let stamp_ok ok proto = { proto with duration_ok = Some (Shared ok) } in
  (* Resolves the sub-picks that fill one chord to [target]. [seed] is the
     entry delay already fixed for the whole group (if any) before the first
     sub-pick runs; [next_seed] derives what becomes fixed for the *next*
     sub-pick from what's fixed so far and the sub-pick just resolved - used
     only by [DurEqualsEntry]'s "settle from the first sub-pick" case below,
     a no-op everywhere else. *)
  let fill_subpicks states target ~seed ~next_seed ~seeds =
    (* [used] carries every instrument already picked earlier in this same
       chord, so a later pick that lands on one of them - the orchestra
       running out of distinct instruments before the target density is
       reached - can be flagged (EMR-3 8.16: "the programme expects there to
       be enough instruments ... If there are not enough instruments, each
       repeated instrument is provided with a comment"). *)
    let rec loop states total used acc settled =
      let states', proto =
        resolve_subpick ?seed_entrydelay:settled ~seeds states
      in
      let picked =
        match proto.instrument with
        | Some (Instrument { instrument; _ }) -> instrument
        | None -> assert false
      in
      let proto = { proto with instrument_repeated = List.mem picked used } in
      let settled' = next_seed settled proto in
      let n = Option.value proto.nr_of_notes ~default:1 in
      let total' = total + n in
      let used' = picked :: used in
      if total' >= target then
        let proto' =
          { proto with nr_of_notes = Some (n - (total' - target)) }
        in
        (settled', List.rev (proto' :: acc), states')
      else loop states' total' used' (proto :: acc) settled'
    in
    loop states 0 [] [] seed
  in
  let keep_seed settled _ = settled in
  (* Draws duration's own whole-chord value using whatever of its two
     dependencies (the instrument, entry delay) is fixed at the point in
     [fill_group] this is called from - [ed_opt] carries whichever is true of
     entry delay ([None] when it isn't decided yet in this branch). Reuses
     [dur_pred_from] exactly as a single sub-pick's own [Dur] step would,
     just fed a placeholder proto with only [entrydelay] (maybe) set. *)
  let draw_duration_before ~ed_opt states =
    let pred =
      dur_pred_from ~instr_arr:states.instr_arr
        { empty_proto with entrydelay = ed_opt }
        dur_relation
    in
    let v, dur_state' = sel_sample_pred_tagged pred states.dur_state in
    let ok = result_ok v in
    let d = get_value v in
    ({ states with dur_state = dur_state' }, Some (Shared d, Shared ok))
  in
  (* The [Ins]-after-[Dur] counterpart: the group is already fully resolved
     (so every sub-pick's instrument is known), constrained to whatever of
     [ed_opt] is already fixed - mirrors [fill_group_with_note_modes]'s own
     aggregate-after-the-loop cases below. *)
  let stamp_duration_after ~ed_opt group states' =
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
    let v, dur_state' = sel_sample_pred_tagged pred states'.dur_state in
    let ok = result_ok v in
    let d = get_value v in
    let group' =
      List.map
        (fun p ->
          { p with duration = Some (Shared d); duration_ok = Some (Shared ok) })
        group
    in
    (group', { states' with dur_state = dur_state' })
  in
  (* Shared tail of the two [Dur]-before-[Ent] branches: draw the group's
     entry delay from whatever duration(s) ended up in the (by now fully
     resolved, including duration) group - unchanged by [dur_extracted],
     since a [PerChord]-extracted duration just means every proto already
     carries the same repeated value, which [max_duration_of] reduces to
     correctly either way. *)
  let finish_with_computed_entrydelay group states' =
    let max_dur =
      group
      |> List.fold_left (fun acc p -> Float.max acc (max_duration_of p)) 0.0
    in
    let pred =
      match dur_relation with
      | DurShorterThanEntry _ -> fun (Entrydelay ed) -> ed >= max_dur
      | DurIndependent _ | DurEqualsEntry -> Fun.const true
    in
    let v, ed_state' = sel_sample_pred_tagged pred states'.ed_state in
    let ok = result_ok v in
    let ed = get_value v in
    let group = List.map (mark_group_ok ok) group in
    (ed, group, { states' with ed_state = ed_state' })
  in
  (* [seeds] carries whichever of performance/dynamics/register are already
     fixed for the whole chord - constant throughout, just threaded through
     unchanged, orthogonal to the entry-delay/duration branching below.
     Duration's own extraction (when applicable) is handled inline in each
     branch instead, since - unlike the other three - it needs to know
     locally whether entry delay is already fixed. *)
  let fill_group ~seeds states target =
    match (dur_relation, ent_before_dur) with
    | DurEqualsEntry, true ->
        (* the drawn value becomes every sub-pick's duration verbatim (below),
           so - exactly like the single-sub-pick case this generalizes - it
           must itself be achievable as *some* instrument's duration. *)
        let pred (Entrydelay ed) =
          dur_pred_from ~instr_arr:states.instr_arr empty_proto dur_relation
            (Duration ed)
        in
        let v, ed_state' = sel_sample_pred_tagged pred states.ed_state in
        let ok = result_ok v in
        let ed = get_value v in
        let states = { states with ed_state = ed_state' } in
        let _, group, states' =
          fill_subpicks states target ~seed:(Some ed) ~next_seed:keep_seed
            ~seeds
        in
        (ed, List.map (stamp_ok ok) group, states')
    | DurEqualsEntry, false ->
        let next_seed settled proto =
          match settled with
          | Some _ -> settled
          | None -> (
              match proto.duration with
              | Some (Shared (Duration d)) -> Some (Entrydelay d)
              | _ -> None)
        in
        let settled, group, states' =
          fill_subpicks states target ~seed:None ~next_seed ~seeds
        in
        (* [duration_note_mode DurEqualsEntry] is always [PerChord], so the
           first sub-pick always settles [settled] to [Some _] via [next_seed]
           above - this can't stay [None]. *)
        let ed = Option.get settled in
        let ok =
          match group with
          | p :: _ -> (
              match p.duration_ok with Some (Shared ok) -> ok | _ -> true)
          | [] -> true
        in
        (ed, List.map (stamp_ok ok) group, states')
    | (DurIndependent _ | DurShorterThanEntry _), true ->
        let v, ed_state' =
          sel_sample_pred_tagged (Fun.const true) states.ed_state
        in
        let ed = get_value v in
        let states = { states with ed_state = ed_state' } in
        if dur_extracted && dur_before_ins then
          let states, dur_seed = draw_duration_before ~ed_opt:(Some ed) states in
          let _, group, states' =
            fill_subpicks states target ~seed:(Some ed) ~next_seed:keep_seed
              ~seeds:{ seeds with cs_dur = dur_seed }
          in
          (ed, group, states')
        else
          let _, group, states' =
            fill_subpicks states target ~seed:(Some ed) ~next_seed:keep_seed
              ~seeds
          in
          if dur_extracted then
            let group, states' =
              stamp_duration_after ~ed_opt:(Some ed) group states'
            in
            (ed, group, states')
          else (ed, group, states')
    | (DurIndependent _ | DurShorterThanEntry _), false ->
        if dur_extracted && dur_before_ins then
          let states, dur_seed = draw_duration_before ~ed_opt:None states in
          let _, group, states' =
            fill_subpicks states target ~seed:None ~next_seed:keep_seed
              ~seeds:{ seeds with cs_dur = dur_seed }
          in
          finish_with_computed_entrydelay group states'
        else
          let _, group, states' =
            fill_subpicks states target ~seed:None ~next_seed:keep_seed ~seeds
          in
          let group, states' =
            if dur_extracted then stamp_duration_after ~ed_opt:None group states'
            else (group, states')
          in
          finish_with_computed_entrydelay group states'
  in
  (* Wraps [fill_group] with whole-chord ([PerChord]) performance/dynamics/
     register resolution - the group-level analogue of [Ent]'s own
     extraction above, but with an extra wrinkle: unlike entry delay, all
     three depend on the instrument, and under [Autonomous] density each
     sub-pick may pick a *different* one. So which side of the fold each
     shared draw happens on depends on where the composer put it relative to
     [Ins]:
     - before [Ins]: draw one value now, using the same "no instrument
       decided yet" existential predicate [resolve_step]'s own case already
       uses when [Ins] hasn't run - then seed it into every sub-pick's
       [start] proto, so each sub-pick's own [Ins] draw is naturally
       filtered to compatible instruments via [ins_pred_from], exactly as it
       would be for a single sub-pick. [Reg]'s predicate also covers
       harmony ([reg_pred_from]), but seeded this early nothing has run for
       anyone yet (including harmony) - so it's simply unconstrained by it,
       same as a single sub-pick's own [Reg] step would be with [Har] still
       unresolved; every sub-pick's own (still in-the-fold) [Har] step then
       agrees with the now-fixed register instead, via [har_pred_from].
     - after [Ins]: every sub-pick picks its own instrument (and, for
       [Reg], resolves its own per-note harmony too - [Ins] always precedes
       [Har], so by the time the whole loop finishes both are known for
       every sub-pick) unconstrained by the not-yet-decided shared value,
       matching what would happen per sub-pick if this weren't extracted at
       all; only afterwards is one value drawn, constrained to agree with
       every picked instrument (and, for [Reg], every already-resolved
       harmony value too), and stamped onto every proto in the group. *)
  let fill_group_with_note_modes states target =
    let states, perf_seed =
      if perf_extracted && perf_before_ins then
        let pred =
          mode_pred_from_instrument ~instr_arr:states.instr_arr
            ~mem:Performance_modes.mem None
            (fun (Instrument { performance; _ }) -> performance)
        in
        let v, perf_state' = sel_sample_pred pred states.perf_state in
        ({ states with perf_state = perf_state' }, Some (Shared v))
      else (states, None)
    in
    let states, dyn_seed =
      if dyn_extracted && dyn_before_ins then
        let pred =
          mode_pred_from_instrument ~instr_arr:states.instr_arr
            ~mem:Dynamic_modes.mem None
            (fun (Instrument { dynamics; _ }) -> dynamics)
        in
        let v, dyn_state' = sel_sample_pred pred states.dyn_state in
        ({ states with dyn_state = dyn_state' }, Some (Shared v))
      else (states, None)
    in
    let states, reg_seed =
      if reg_extracted && reg_before_ins then
        let pred = reg_pred_from ~instr_arr:states.instr_arr empty_proto in
        let v, reg_state' = sel_sample_pred_tagged pred states.reg_state in
        let ok = result_ok v in
        let r = get_value v in
        ( { states with reg_state = reg_state' },
          Some (Shared r, Shared ok) )
      else (states, None)
    in
    let seeds =
      { no_chord_seeds with cs_perf = perf_seed; cs_dyn = dyn_seed; cs_reg = reg_seed }
    in
    let ed, group, states' = fill_group ~seeds states target in
    let group, states' =
      if perf_extracted && not perf_before_ins then
        let pred v =
          List.for_all
            (fun (Instrument { performance = modes; _ }) ->
              Performance_modes.mem v modes)
            (instruments_of group)
        in
        let v, perf_state' = sel_sample_pred pred states'.perf_state in
        ( List.map (fun p -> { p with performance = Some (Shared v) }) group,
          { states' with perf_state = perf_state' } )
      else (group, states')
    in
    let group, states' =
      if dyn_extracted && not dyn_before_ins then
        let pred v =
          List.for_all
            (fun (Instrument { dynamics = modes; _ }) -> Dynamic_modes.mem v modes)
            (instruments_of group)
        in
        let v, dyn_state' = sel_sample_pred pred states'.dyn_state in
        ( List.map (fun p -> { p with dynamic = Some (Shared v) }) group,
          { states' with dyn_state = dyn_state' } )
      else (group, states')
    in
    let group, states' =
      if reg_extracted && not reg_before_ins then
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
        let v, reg_state' = sel_sample_pred_tagged pred states'.reg_state in
        let ok = result_ok v in
        let r = get_value v in
        ( List.map
            (fun p -> { p with register = Some (Shared r); register_ok = Some (Shared ok) })
            group,
          { states' with reg_state = reg_state' } )
      else (group, states')
    in
    (ed, group, states')
  in
  let final_states, _, groups =
    List.init n_events (fun _ -> ())
    |> List.fold_left
         (fun (states, dens_state, acc) () ->
           let target, dens_state' = sel_sample dens_state in
           let ed, group, states' = fill_group_with_note_modes states target in
           ( advance_all_windows states',
             sel_advance_window dens_state',
             (ed, group) :: acc ))
         (states0, sel_init selection_principle n_events dens_arr, [])
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
  List.init n (fun i ->
      let pitch, agree_ok = resolve_pitch (value_at reg i) (value_at har i) in
      let pitch_ok = agree_ok && value_at reg_ok i && value_at har_ok i in
      {
        time = 0.0;
        instrument = instr;
        performance = value_at perf i;
        dynamic = value_at dyn i;
        duration = value_at dur i;
        duration_ok = value_at dur_ok i;
        pitch;
        pitch_ok;
        instrument_repeated = proto.instrument_repeated;
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
   [entrydelay] is likewise the group's, never any individual sub-pick's. *)
let entry_of_group time (Entrydelay ed) (protos : proto list) : entry =
  let notes =
    protos
    |> List.concat_map notes_of_proto
    |> List.map (fun (n : note) -> { n with time })
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
      List.exists (fun (n : note) -> n.instrument_repeated) notes;
  }

(* Pure fold: sums each group's own (single, shared) entry delay into a
   running absolute time, stamping that time onto the finished entry. *)
let resolve_times (groups : (entrydelay * proto list) list) : entry list =
  let _, entries =
    List.fold_left
      (fun (t, acc) (ed, protos) ->
        let (Entrydelay edf) = ed in
        (t +. edf, entry_of_group t ed protos :: acc))
      (0.0, []) groups
  in
  List.rev entries

let calculate_layer_hierarchical ~n_events ~variant_n_events ~hierarchy
    ~instr_arr ~instr_principle ~ed_arr ~ed_principle ~perf_arr ~perf_principle
    ~perf_mode ~dyn_arr ~dyn_principle ~dyn_mode ~dur_arr ~dur_principle
    ~dur_relation ~reg_arr ~reg_principle ~reg_mode ~density
    (continuing : continuing_state) =
  let states0 =
    {
      instr_state =
        continue_or_restart ~principle:instr_principle ~n:variant_n_events
          ~last_arr:continuing.instr_last_arr ~arr:instr_arr
          continuing.instr_state;
      ed_state =
        continue_or_restart ~principle:ed_principle ~n:variant_n_events
          ~last_arr:continuing.ed_last_arr ~arr:ed_arr continuing.ed_state;
      perf_state =
        continue_or_restart ~principle:perf_principle ~n:variant_n_events
          ~last_arr:continuing.perf_last_arr ~arr:perf_arr
          continuing.perf_state;
      dyn_state =
        continue_or_restart ~principle:dyn_principle ~n:variant_n_events
          ~last_arr:continuing.dyn_last_arr ~arr:dyn_arr continuing.dyn_state;
      dur_state =
        continue_or_restart ~principle:dur_principle ~n:variant_n_events
          ~last_arr:continuing.dur_last_arr ~arr:dur_arr continuing.dur_state;
      reg_state =
        continue_or_restart ~principle:reg_principle ~n:variant_n_events
          ~last_arr:continuing.reg_last_arr ~arr:reg_arr continuing.reg_state;
      har_state = continuing.har_state;
      instr_arr = Array.map value_from_element instr_arr;
      instr_last_arr = instr_arr;
      ed_last_arr = ed_arr;
      perf_last_arr = perf_arr;
      dyn_last_arr = dyn_arr;
      dur_last_arr = dur_arr;
      reg_last_arr = reg_arr;
    }
  in
  let groups, states' =
    match density with
    | InstrumentDensity ->
        resolve_layer_instrument_density ~n_events ~hierarchy ~perf_mode
          ~dyn_mode ~dur_relation ~reg_mode states0
    | Autonomous { low; high; selection_principle } ->
        resolve_layer_autonomous ~n_events ~hierarchy ~perf_mode ~dyn_mode
          ~dur_relation ~reg_mode ~low ~high ~selection_principle
          states0
  in
  (resolve_times groups, states')

let zip6 a b c d e f =
  List.map2
    (fun (x, y) (z, (w, (v, u))) -> (x, y, z, w, v, u))
    (List.combine a b)
    (List.combine c (List.combine d (List.combine e f)))

(* TENDENCY's window schedule is scoped to one variant by definition (EMR-3
   p.47: its "number of results" is the total for "the given variant") -
   unlike every other principle, which only resets at a new variant group,
   it resets at the start of every variant. Every other field passes
   through untouched, continuing exactly as it already does across layers. *)
let start_new_variant ~variant_n_events (continuing : continuing_state) =
  let reset_if_tendency state arr =
    match state with
    | STendency (TendencyState { spec; _ }) ->
        STendency
          (tendency_init ~count:variant_n_events
             (Array.map value_from_element arr) spec)
    | _ -> state
  in
  {
    continuing with
    instr_state =
      reset_if_tendency continuing.instr_state continuing.instr_last_arr;
    ed_state = reset_if_tendency continuing.ed_state continuing.ed_last_arr;
    perf_state =
      reset_if_tendency continuing.perf_state continuing.perf_last_arr;
    dyn_state = reset_if_tendency continuing.dyn_state continuing.dyn_last_arr;
    dur_state = reset_if_tendency continuing.dur_state continuing.dur_last_arr;
    reg_state = reset_if_tendency continuing.reg_state continuing.reg_last_arr;
  }

let generate_score_hierarchical ~variant_duration ~instrument_ensemble
    ~instrument_principle ~entry_delay_ensemble ~entry_delay_principle
    ~perf_ensemble ~perf_principle ~perf_mode ~dyn_ensemble ~dyn_principle
    ~dyn_mode ~dur_ensemble ~dur_principle ~dur_relation ~reg_ensemble
    ~reg_principle ~reg_mode ~union ~hierarchy ~density
    (continuing : continuing_state) =
  match union with
  | Union ->
      let entr_arr = ensemble_values_union entry_delay_ensemble in
      let instr_arr = ensemble_values_union instrument_ensemble in
      let perf_arr = ensemble_values_union perf_ensemble in
      let dyn_arr = ensemble_values_union dyn_ensemble in
      let dur_arr = ensemble_values_union dur_ensemble in
      let reg_arr = ensemble_values_union reg_ensemble in
      let n_events =
        calculate_number_of_events variant_duration entry_delay_principle
          entr_arr
      in
      let _ = Printf.printf "estimated events: %d\n" n_events in
      let continuing = start_new_variant ~variant_n_events:n_events continuing in
      let entries, continuing' =
        calculate_layer_hierarchical ~n_events ~variant_n_events:n_events
          ~hierarchy ~instr_arr ~instr_principle:instrument_principle
          ~ed_arr:entr_arr ~ed_principle:entry_delay_principle ~perf_arr
          ~perf_principle ~perf_mode ~dyn_arr ~dyn_principle ~dyn_mode ~dur_arr
          ~dur_principle ~dur_relation ~reg_arr ~reg_principle ~reg_mode
 ~density continuing
      in
      ([ entries ], continuing')
  | NoUnion ->
      let instr_arrays = ensemble_values_no_union instrument_ensemble in
      let entr_arrays = ensemble_values_no_union entry_delay_ensemble in
      let perf_arrays = ensemble_values_no_union perf_ensemble in
      let dyn_arrays = ensemble_values_no_union dyn_ensemble in
      let dur_arrays = ensemble_values_no_union dur_ensemble in
      let reg_arrays = ensemble_values_no_union reg_ensemble in
      let layer_inputs =
        zip6 instr_arrays entr_arrays perf_arrays dyn_arrays dur_arrays
          reg_arrays
      in
      (* TENDENCY's window schedule is sized from the whole variant's total
         event count (EMR-3 p.47: "N = number of time-points in variant"),
         not any one layer's own - computed once, up front, and reused for
         every layer's [Tendency]-tagged field via [continue_or_restart]. *)
      let variant_n_events =
        layer_inputs
        |> List.fold_left
             (fun acc (_, entr_arr, _, _, _, _) ->
               acc
               + calculate_number_of_events variant_duration
                   entry_delay_principle entr_arr)
             0
      in
      let continuing = start_new_variant ~variant_n_events continuing in
      let continuing', layers =
        List.fold_left_map
          (fun continuing
               (instr_arr, entr_arr, perf_arr, dyn_arr, dur_arr, reg_arr) ->
            let n_events =
              calculate_number_of_events variant_duration
                entry_delay_principle entr_arr
            in
            let _ = Printf.printf "\nestimated events: %d " n_events in
            let entries, continuing' =
              calculate_layer_hierarchical ~n_events ~variant_n_events
                ~hierarchy ~instr_arr ~instr_principle:instrument_principle
                ~ed_arr:entr_arr ~ed_principle:entry_delay_principle ~perf_arr
                ~perf_principle ~perf_mode ~dyn_arr ~dyn_principle ~dyn_mode
                ~dur_arr ~dur_principle ~dur_relation ~reg_arr ~reg_principle
                ~reg_mode ~density continuing
            in
            (continuing', entries))
          continuing layer_inputs
      in
      (layers, continuing')

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
    | NoUnion -> cfg.number_of_instrument_groups
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
  let continuing0 =
    initial_continuing_state ~tr:cfg.tr ~transposition:cfg.transposition
      cfg.row
  in
  (* One [generate_score_hierarchical] call per variant, [continuing]
     threaded from the last variant into the next exactly as it already
     threads from layer to layer within one - the fresh start EMR-3 grants
     only belongs to a genuinely new variant *group* (a new seed), never to
     a variant within this one run. *)
  let (_ : continuing_state), variants =
    List.fold_left_map
      (fun continuing v ->
        let layers, continuing' =
          generate_score_hierarchical ~variant_duration:cfg.variant_duration
            ~instrument_ensemble:instr_ensembles.(v)
            ~instrument_principle:cfg.instrument_principle
            ~entry_delay_ensemble:(ed_ensemble_for v)
            ~entry_delay_principle:cfg.entrydelay_principle
            ~perf_ensemble:(perf_ensemble_for v)
            ~perf_principle:cfg.performance_principle
            ~perf_mode:cfg.performance_mode
            ~dyn_ensemble:(dyn_ensemble_for v)
            ~dyn_principle:cfg.dynamics_principle ~dyn_mode:cfg.dynamics_mode
            ~dur_ensemble:(dur_ensemble_for v)
            ~dur_principle:cfg.duration_principle
            ~dur_relation:cfg.duration_relation_mode
            ~reg_ensemble:(reg_ensemble_for v)
            ~reg_principle:cfg.register_principle ~reg_mode:cfg.register_mode
 ~union:cfg.union
            ~hierarchy:cfg.hierarchy ~density:cfg.density continuing
        in
        (continuing', layers))
      continuing0
      (List.init cfg.n_variants (fun v -> v))
  in
  variants

let build_constraint_map instrs =
  List.map
    (fun (Instrument { instrument; performance; dynamics; durations; _ }) ->
      (instrument, (performance, dynamics, durations)))
    instrs

(* Describe what, if anything, is wrong with a note's performance/dynamic/
   duration given the instrument's allowed modes and duration range. Empty
   list means the note is fine. *)
let instrument_repeated_problem (note : note) =
  if note.instrument_repeated then
    [
      "instrument reused within this chord (not enough distinct instruments to \
       reach the vertical density)";
    ]
  else []

let note_problems constraint_map (note : note) =
  instrument_repeated_problem note
  @
  match List.assoc_opt note.instrument constraint_map with
  | None -> [ "unknown instrument" ]
  | Some (valid_perfs, valid_dyns, valid_durs) ->
      let perf_problem =
        if Performance_modes.mem note.performance valid_perfs then []
        else
          let valid_perfs_str =
            Performance_modes.elements valid_perfs
            |> List.map Performance.to_string
            |> String.concat ", "
          in
          [
            Printf.sprintf "performance '%s' (valid: %s)"
              (Performance.to_string note.performance)
              valid_perfs_str;
          ]
      in
      let dyn_problem =
        if Dynamic_modes.mem note.dynamic valid_dyns then []
        else
          let valid_dyns_str =
            Dynamic_modes.elements valid_dyns
            |> List.map Dynamic.to_string |> String.concat ", "
          in
          [
            Printf.sprintf "dynamic '%s' (valid: %s)"
              (Dynamic.to_string note.dynamic)
              valid_dyns_str;
          ]
      in
      let dur_problem =
        let (Duration d) = note.duration in
        if duration_range_ok valid_durs note.duration then []
        else
          let (AllowedDurations { min; max }) = valid_durs in
          [ Printf.sprintf "duration %.3f (valid: %.3f-%.3f)" d min max ]
      in
      let dur_relation_problem =
        if note.duration_ok then []
        else
          let (Duration d) = note.duration in
          [
            Printf.sprintf
              "duration %.3f could not satisfy the entry-delay relation (no \
               valid candidate existed)"
              d;
          ]
      in
      let pitch_problem =
        if note.pitch_ok then []
        else
          [
            Printf.sprintf
              "pitch %s did not agree between register and harmony"
              (pitch_to_string note.pitch);
          ]
      in
      perf_problem @ dyn_problem @ dur_problem @ dur_relation_problem
      @ pitch_problem

(* Aligns rows of already-stringified cells by padding each column to its
   widest value. Knows nothing about score events, so it can't drift out of
   sync with whatever ends up being printed. *)
module Table = struct
  let column_widths = function
    | [] -> []
    | row :: _ as rows ->
        let init = List.map (fun _ -> 0) row in
        List.fold_left
          (List.map2 (fun w cell -> max w (String.length cell)))
          init rows

  let render_row widths row =
    List.map2
      (fun w cell -> cell ^ String.make (max 0 (w - String.length cell)) ' ')
      widths row
    |> String.concat " "
end

(* [entrydelay] comes from the note's owning [entry] - a note itself doesn't
   carry one (see [note]'s definition). *)
let note_cells ~entrydelay (note : note) =
  let (InstrumentName name) = note.instrument in
  let (Duration d) = note.duration in
  [
    Printf.sprintf "%.3f" note.time;
    Printf.sprintf "%.3f" entrydelay;
    Printf.sprintf "%.3f" d;
    name;
    Performance.to_string note.performance;
    Dynamic.to_string note.dynamic;
    pitch_to_string note.pitch;
  ]

let note_header =
  [
    "time";
    "entrydelay";
    "duration";
    "instrument";
    "performance";
    "dynamic";
    "pitch";
  ]

(* Flat view: one row per note (a multi-note chord produces several rows
   sharing the same time), ignoring entry grouping entirely. *)
let opt_to_string to_string = function Some v -> to_string v | None -> "-"
let instrument_name_opt = opt_to_string (fun (InstrumentName n) -> n)

let cells_for_entry_notes (e : entry) =
  List.map (fun (n : note) -> note_cells ~entrydelay:e.entrydelay n) e.notes

let write_notes_score filename instrs (layers : entry list list) =
  let constraint_map = build_constraint_map instrs in
  let all_rows =
    note_header
    :: (layers |> List.concat_map (List.concat_map cells_for_entry_notes))
  in
  let widths = Table.column_widths all_rows in
  let oc = open_out filename in
  List.iteri
    (fun i (entries : entry list) ->
      Printf.fprintf oc "# layer %d\n" i;
      entries
      |> List.iter (fun (e : entry) ->
          e.notes
          |> List.iter (fun note ->
              Printf.fprintf oc "%s"
                (Table.render_row widths
                   (note_cells ~entrydelay:e.entrydelay note));
              (match note_problems constraint_map note with
              | [] -> ()
              | problems ->
                  Printf.fprintf oc " # IMPOSSIBLE: %s"
                    (String.concat ", " problems));
              Printf.fprintf oc "\n")))
    layers;
  close_out oc

(* The autonomous-density target sampled for [e] - always exactly the number
   of notes it ended up with, since [resolve_layer_autonomous]'s [fill_group]
   fills each chord to precisely that count. Shown as "-" under
   [InstrumentDensity], where note count is just the picked instrument's own
   chordsize, not a density the composer's algorithm chose. *)
let density_cell density (e : entry) =
  match density with
  | Autonomous _ -> string_of_int (List.length e.notes)
  | InstrumentDensity -> "-"

let density_header_comment = function
  | Autonomous { low; high; _ } ->
      Printf.sprintf "# density: autonomous (low %d, high %d)\n" low high
  | InstrumentDensity -> "# density: instrument\n"

(* Hierarchical view: one header line per entry (time, instrument, note
   count, and whichever of performance/dynamic/duration were chord-wide),
   followed by its notes indented underneath. [instrument] is "-" when an
   entry's notes span more than one instrument (EMR-3 8.16 "scoring"). *)
let write_entries_score filename instrs ~density (layers : entry list list) =
  let constraint_map = build_constraint_map instrs in
  let entry_cells (e : entry) =
    [
      Printf.sprintf "%.3f" e.time;
      Printf.sprintf "%.3f" e.entrydelay;
      opt_to_string (fun (Duration d) -> Printf.sprintf "%.3f" d) e.duration;
      instrument_name_opt e.instrument;
      string_of_int (List.length e.notes);
      density_cell density e;
      opt_to_string Performance.to_string e.performance;
      opt_to_string Dynamic.to_string e.dynamic;
      opt_to_string pitch_to_string e.pitch;
    ]
  in
  let entry_header =
    [
      "time";
      "entrydelay";
      "duration";
      "instrument";
      "notes";
      "density";
      "performance";
      "dynamic";
      "pitch";
    ]
  in
  let all_entry_rows =
    entry_header :: (layers |> List.concat_map (List.map entry_cells))
  in
  let entry_widths = Table.column_widths all_entry_rows in
  let all_note_rows =
    note_header
    :: (layers |> List.concat_map (List.concat_map cells_for_entry_notes))
  in
  let note_widths = Table.column_widths all_note_rows in
  let oc = open_out filename in
  Printf.fprintf oc "%s" (density_header_comment density);
  List.iteri
    (fun i (entries : entry list) ->
      Printf.fprintf oc "# layer %d\n" i;
      entries
      |> List.iter (fun (e : entry) ->
          Printf.fprintf oc "%s\n"
            (Table.render_row entry_widths (entry_cells e));
          e.notes
          |> List.iter (fun note ->
              Printf.fprintf oc "    %s"
                (Table.render_row note_widths
                   (note_cells ~entrydelay:e.entrydelay note));
              (match note_problems constraint_map note with
              | [] -> ()
              | problems ->
                  Printf.fprintf oc " # IMPOSSIBLE: %s"
                    (String.concat ", " problems));
              Printf.fprintf oc "\n")))
    layers;
  close_out oc

let print_layers instrs (layers : entry list list) =
  let constraint_map = build_constraint_map instrs in
  let total_violations = ref 0 in
  print_endline "\n=== instrument_entry_test ===";
  List.iteri
    (fun i (entries : entry list) ->
      Printf.printf "\n--- layer %d ---\n" i;
      Printf.printf "%-8s %-10s %-8s %-14s %-5s %-12s %-8s %s\n" "time"
        "entrydelay" "duration" "instrument" "notes" "performance" "dynamic"
        "status";
      entries
      |> List.iter (fun (e : entry) ->
          e.notes
          |> List.iter (fun (note : note) ->
              let problems = note_problems constraint_map note in
              let status =
                match problems with
                | [] -> ""
                | ps ->
                    incr total_violations;
                    "!! IMPOSSIBLE: " ^ String.concat ", " ps
              in
              let (Duration d) = note.duration in
              let (InstrumentName name) = note.instrument in
              Printf.printf "%-8.3f %-10.3f %-8.3f %-14s %-5d %-12s %-8s %s\n"
                note.time e.entrydelay d name (List.length e.notes)
                (Performance.to_string note.performance)
                (Dynamic.to_string note.dynamic)
                status)))
    layers;
  print_endline "";
  if !total_violations = 0 then
    print_endline
      "OK: every performance, dynamic, duration and pitch is valid for its \
       instrument"
  else
    Printf.printf
      "VIOLATIONS: %d note(s) have invalid performance/dynamic/duration/pitch\n"
      !total_violations
