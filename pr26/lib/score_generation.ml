open Parameters
open Structure_formula
open Selection
open Tools

(* A resolved tone-within-a-chord: fully-specified, no options. *)
type note = {
  time : float;
  entrydelay : float;
  instrument : instr;
  performance : Performance.t;
  dynamic : Dynamic.t;
  duration : duration;
  (* [false] iff this duration was an [Impossible] fallback: no candidate
     actually satisfied the duration/entry-delay relation. *)
  duration_ok : bool;
}

(* One instrument's contribution at one timepoint. [performance]/[dynamic]/
   [duration] are [Some] when that parameter was chord-wide (shared across
   every note here), [None] when it was resolved per-tone instead (in which
   case each [note] already carries its own independently-resolved value). *)
type entry = {
  time : float;
  entrydelay : float;
  instrument : instr;
  notes : note list;
  performance : Performance.t option;
  dynamic : Dynamic.t option;
  duration : duration option;
}

(* Extract all elements from any ensemble as a flat array. Each element
   keeps the LIST index it was resolved from (not just its value) so that
   RATIO can weight by original LIST index rather than by ensemble
   position - see [sel_init]'s [Ratio] branch. *)
let ensemble_values_union ensemble =
  match ensemble with
  | Ensemble groups -> groups |> List.map elements_from_indexed_ensemble |> Array.concat
  | SingleGroup elm -> elm |> elements_from_indexed_ensemble

let ensemble_values_no_union ensemble =
  match ensemble with
  | Ensemble groups -> groups |> List.map elements_from_indexed_ensemble
  | SingleGroup g -> [ g |> elements_from_indexed_ensemble ]

(* ---- Pure stateful selector ---- *)
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
   entries sharing an autonomous-density timepoint, or several tones within
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

let calculate_number_of_events variant_duration entry_delay_principle
    entry_delay_ensemble =
  let avg_ed = expected_value entry_delay_principle entry_delay_ensemble in
  int_of_float (floor (variant_duration /. avg_ed))

(* ---- Hierarchical entry resolution ---- *)

(* A parameter that can be chord-wide or per-tone (MOD-DUR/MOD-DYN/MOD-PERF)
   ends up either as one [Shared] value copied to every tone, or as one
   independently-resolved value [PerTone] per tone. *)
type 'a tone_value = Shared of 'a | PerTone of 'a list

let value_at tone_values i =
  match tone_values with Shared v -> v | PerTone vs -> List.nth vs i

(* In-progress entry while the hierarchy fold runs: everything starts [None]
   and gets filled in hierarchy order. [nr_of_tones] is filled as soon as
   [Ins] runs (chordsize is a property of the picked instrument). *)
type proto = {
  entrydelay : entrydelay option;
  instrument : instrument option;
  nr_of_tones : int option;
  performance : Performance.t tone_value option;
  dynamic : Dynamic.t tone_value option;
  duration : duration tone_value option;
  (* [false] iff no candidate duration actually satisfied the duration/
     entry-delay relation and this tone's value is an [Impossible] fallback. *)
  duration_ok : bool tone_value option;
}

let empty_proto =
  {
    entrydelay = None;
    instrument = None;
    nr_of_tones = None;
    performance = None;
    dynamic = None;
    duration = None;
    duration_ok = None;
  }

(* States threaded through the hierarchy fold — one per parameter hierarchy
   controls. [instr_arr] is kept here so a step can constrain itself to
   values achievable by at least one instrument in this group, even before
   [Ins] has run. *)
type layer_states = {
  instr_state : instrument sel_state;
  ed_state : entrydelay sel_state;
  perf_state : Performance.t sel_state;
  dyn_state : Dynamic.t sel_state;
  dur_state : duration sel_state;
  instr_arr : instrument array;
}

let advance_all_windows states =
  {
    states with
    instr_state = sel_advance_window states.instr_state;
    ed_state = sel_advance_window states.ed_state;
    perf_state = sel_advance_window states.perf_state;
    dyn_state = sel_advance_window states.dyn_state;
    dur_state = sel_advance_window states.dur_state;
  }

(* Resolve one chord-wide-or-per-tone parameter at its hierarchy position:
   [PerChord] draws once and shares it across every tone; [PerTone] draws
   independently once per tone. [n_tones] must already be known (an
   instrument, and hence chordsize, is required to precede any per-tone
   parameter - enforced at formula-load time by
   [Structure_formula.mk_structure_formula]'s per-tone-ordering check). *)
(* Same as [resolve_tone_param], but also reports, per tone, whether its
   value actually satisfied [pred] (vs. being an [Impossible] fallback) - so
   a caller that cares (duration, re: the entry-delay relation) can flag it,
   while one that doesn't (performance, dynamics) just ignores the flags. *)
let resolve_tone_param_tagged mode n_tones pred state =
  match mode with
  | PerChord ->
      let v, state' = sel_sample_pred_tagged pred state in
      let ok = match v with Value _ -> true | Impossible _ -> false in
      (Shared (get_value v), Shared ok, state')
  | PerTone ->
      let n = Option.value n_tones ~default:1 in
      let vs, oks, state' =
        List.init n (fun _ -> ())
        |> List.fold_left
             (fun (acc, oks_acc, st) () ->
               let v, st' = sel_sample_pred_tagged pred st in
               let ok = match v with Value _ -> true | Impossible _ -> false in
               (get_value v :: acc, ok :: oks_acc, st'))
             ([], [], state)
      in
      (PerTone (List.rev vs), PerTone (List.rev oks), state')

let resolve_tone_param mode n_tones pred state =
  let values, _oks, state' = resolve_tone_param_tagged mode n_tones pred state in
  (values, state')

let duration_range_ok (AllowedDurations { min; max }) (Duration d) =
  min <= d && d <= max

(* [Ins]'s predicate: an instrument must be compatible with whatever of
   performance/dynamic/duration has already been resolved for this entry (if
   any) - the same "constrain on what's already chosen" idea used
   symmetrically by [Per]/[Dyn]/[Dur] below when [Ins] hasn't run yet. For a
   per-tone value, *every* tone's value must fit the instrument (EMR-3
   7.3: "if the durations in the chord are equal, instruments can only be
   selected which can play the selected duration; if not the same, this
   question is posed for each duration and instrument"). *)
let ins_pred_from proto =
  let from_perf (Instrument { performance = modes; _ }) =
    match proto.performance with
    | None -> true
    | Some (Shared p) -> Performance_modes.mem p modes
    | Some (PerTone ps) -> List.for_all (fun p -> Performance_modes.mem p modes) ps
  in
  let from_dyn (Instrument { dynamics = modes; _ }) =
    match proto.dynamic with
    | None -> true
    | Some (Shared d) -> Dynamic_modes.mem d modes
    | Some (PerTone ds) -> List.for_all (fun d -> Dynamic_modes.mem d modes) ds
  in
  let from_dur (Instrument { durations; _ }) =
    match proto.duration with
    | None -> true
    | Some (Shared d) -> duration_range_ok durations d
    | Some (PerTone ds) -> List.for_all (duration_range_ok durations) ds
  in
  fun i -> from_perf i && from_dyn i && from_dur i

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

let duration_tone_mode = function
  | DurIndependent m -> m
  | DurEqualsEntry -> PerChord
  | DurShorterThanEntry m -> m

(* Entry delay's own conditioning: unconstrained, unless DUR-ENTRY requires
   it to follow duration (which must then already be known). *)
let ed_pred_from proto dur_relation =
  match (dur_relation, proto.duration) with
  | DurShorterThanEntry _, Some (Shared (Duration d)) ->
      fun (Entrydelay ed) -> ed >= d
  | DurShorterThanEntry _, Some (PerTone ds) ->
      let max_d = ds |> List.map (fun (Duration d) -> d) |> List.fold_left Float.max 0.0 in
      fun (Entrydelay ed) -> ed >= max_d
  | _ -> Fun.const true

(* One hierarchy element's worth of work for one entry. This is the single
   place that knows how [Ins]/[Ent]/[Dur]/[Per]/[Dyn] each condition on, or
   get conditioned by, one another - both density modes below just fold this
   over the composer's [hierarchy] list once per entry. *)
let resolve_step ~perf_mode ~dyn_mode ~dur_relation (states, proto) elem =
  match elem with
  | Ins ->
      let v, instr_state' = sel_sample_pred (ins_pred_from proto) states.instr_state in
      let (Instrument { chordsize = Chordsize { minsize; maxsize }; _ }) = v in
      let n = if minsize = maxsize then minsize else Random.int (maxsize - minsize + 1) + minsize in
      ( { states with instr_state = instr_state' },
        { proto with instrument = Some v; nr_of_tones = Some n } )
  | Ent -> (
      match (dur_relation, proto.duration) with
      | DurEqualsEntry, Some (Shared (Duration d)) ->
          (states, { proto with entrydelay = Some (Entrydelay d) })
      | _ ->
          let pred = ed_pred_from proto dur_relation in
          let v, ed_state' = sel_sample_pred pred states.ed_state in
          ({ states with ed_state = ed_state' }, { proto with entrydelay = Some v }))
  | Dur -> (
      match (dur_relation, proto.entrydelay) with
      | DurEqualsEntry, Some (Entrydelay ed) ->
          let d =
            match proto.instrument with
            | Some (Instrument { durations = AllowedDurations { max; _ }; _ }) ->
                Float.min ed max
            | None -> ed
          in
          ( states,
            { proto with duration = Some (Shared (Duration d)); duration_ok = Some (Shared true) }
          )
      | _ ->
          let mode = duration_tone_mode dur_relation in
          let pred = dur_pred_from ~instr_arr:states.instr_arr proto dur_relation in
          let v, oks, dur_state' =
            resolve_tone_param_tagged mode proto.nr_of_tones pred states.dur_state
          in
          ( { states with dur_state = dur_state' },
            { proto with duration = Some v; duration_ok = Some oks } ))
  | Per ->
      let pred =
        mode_pred_from_instrument ~instr_arr:states.instr_arr ~mem:Performance_modes.mem
          proto.instrument
          (fun (Instrument { performance; _ }) -> performance)
      in
      let v, perf_state' = resolve_tone_param perf_mode proto.nr_of_tones pred states.perf_state in
      ({ states with perf_state = perf_state' }, { proto with performance = Some v })
  | Dyn ->
      let pred =
        mode_pred_from_instrument ~instr_arr:states.instr_arr ~mem:Dynamic_modes.mem
          proto.instrument
          (fun (Instrument { dynamics; _ }) -> dynamics)
      in
      let v, dyn_state' = resolve_tone_param dyn_mode proto.nr_of_tones pred states.dyn_state in
      ({ states with dyn_state = dyn_state' }, { proto with dynamic = Some v })

let resolve_entry ~hierarchy ~perf_mode ~dyn_mode ~dur_relation states =
  List.fold_left (resolve_step ~perf_mode ~dyn_mode ~dur_relation) (states, empty_proto) hierarchy

(* All entries in an autonomous-density timepoint group share one start
   time: only the last one's drawn entry delay survives to advance the
   running clock, earlier ones are stamped to 0 so step 2's summing fold
   doesn't move between them. *)
let stamp_group_entrydelay group =
  let n = List.length group in
  List.mapi
    (fun i proto ->
      if i = n - 1 then proto else { proto with entrydelay = Some (Entrydelay 0.0) })
    group

(** With [InstrumentDensity], every entry is its own timepoint. *)
let resolve_layer_instrument_density ~n_events ~hierarchy ~perf_mode ~dyn_mode
    ~dur_relation states0 =
  let _, protos =
    List.init n_events (fun _ -> ())
    |> List.fold_left
         (fun (states, acc) () ->
           let states', proto = resolve_entry ~hierarchy ~perf_mode ~dyn_mode ~dur_relation states in
           (advance_all_windows states', proto :: acc))
         (states0, [])
  in
  List.rev protos

(** With [Autonomous] density, each timepoint samples a target density and
    keeps resolving entries (each independently picking its own instrument,
    conditioned the same way as any other entry) until the target is
    reached. If the last pick's chordsize would overshoot the target, its
    extra voices are cut - [nr_of_tones] is capped down to however many are
    still needed, so the group's total lands exactly on the target. (Any
    per-tone performance/dynamic/duration values already drawn for the
    trimmed voices are simply never read - [notes_of_proto] only builds as
    many notes as [nr_of_tones] says.) *)
let resolve_layer_autonomous ~n_events ~hierarchy ~perf_mode ~dyn_mode
    ~dur_relation ~low ~high ~selection_principle states0 =
  let dens_arr = Array.init (high - low + 1) (fun i -> low + i) |> elements_of_array in
  let fill_group states target =
    let rec loop states total acc =
      let states', proto = resolve_entry ~hierarchy ~perf_mode ~dyn_mode ~dur_relation states in
      let n = Option.value proto.nr_of_tones ~default:1 in
      let total' = total + n in
      if total' >= target then
        let proto' = { proto with nr_of_tones = Some (n - (total' - target)) } in
        (List.rev (proto' :: acc), states')
      else loop states' total' (proto :: acc)
    in
    loop states 0 []
  in
  let _, _, groups =
    List.init n_events (fun _ -> ())
    |> List.fold_left
         (fun (states, dens_state, acc) () ->
           let target, dens_state' = sel_sample dens_state in
           let group, states' = fill_group states target in
           ( advance_all_windows states',
             sel_advance_window dens_state',
             stamp_group_entrydelay group :: acc ))
         (states0, sel_init selection_principle n_events dens_arr, [])
  in
  groups |> List.rev |> List.concat

(* ---- Step 2: turn resolved protos into the final score (entries + notes) ---- *)

let notes_of_proto time entrydelay proto =
  let instr = match proto.instrument with Some (Instrument { instrument; _ }) -> instrument | None -> assert false in
  let n = Option.value proto.nr_of_tones ~default:1 in
  let perf = match proto.performance with Some tv -> tv | None -> assert false in
  let dyn = match proto.dynamic with Some tv -> tv | None -> assert false in
  let dur = match proto.duration with Some tv -> tv | None -> assert false in
  let dur_ok = match proto.duration_ok with Some tv -> tv | None -> assert false in
  List.init n (fun i ->
      {
        time;
        entrydelay;
        instrument = instr;
        performance = value_at perf i;
        dynamic = value_at dyn i;
        duration = value_at dur i;
        duration_ok = value_at dur_ok i;
      })

let entry_of_proto time entrydelay proto =
  let instr = match proto.instrument with Some (Instrument { instrument; _ }) -> instrument | None -> assert false in
  let shared_only = function Some (Shared v) -> Some v | Some (PerTone _) | None -> None in
  {
    time;
    entrydelay;
    instrument = instr;
    notes = notes_of_proto time entrydelay proto;
    performance = shared_only proto.performance;
    dynamic = shared_only proto.dynamic;
    duration = shared_only proto.duration;
  }

(* Pure fold: sums each proto's own entry delay into a running absolute
   time, stamping that time onto the finished entry (and its notes). *)
let resolve_times (protos : proto list) : entry list =
  let _, entries =
    List.fold_left
      (fun (t, acc) proto ->
        let ed = match proto.entrydelay with Some (Entrydelay ed) -> ed | None -> 0.0 in
        (t +. ed, entry_of_proto t ed proto :: acc))
      (0.0, []) protos
  in
  List.rev entries

let calculate_layer_hierarchical ~n_events ~hierarchy ~instr_arr
    ~instr_principle ~ed_arr ~ed_principle ~perf_arr ~perf_principle ~perf_mode
    ~dyn_arr ~dyn_principle ~dyn_mode ~dur_arr ~dur_principle ~dur_relation
    ~density =
  let states0 =
    {
      instr_state = sel_init instr_principle n_events instr_arr;
      ed_state = sel_init ed_principle n_events ed_arr;
      perf_state = sel_init perf_principle n_events perf_arr;
      dyn_state = sel_init dyn_principle n_events dyn_arr;
      dur_state = sel_init dur_principle n_events dur_arr;
      instr_arr = Array.map value_from_element instr_arr;
    }
  in
  let protos =
    match density with
    | InstrumentDensity ->
        resolve_layer_instrument_density ~n_events ~hierarchy ~perf_mode ~dyn_mode ~dur_relation states0
    | Autonomous { low; high; selection_principle } ->
        resolve_layer_autonomous ~n_events ~hierarchy ~perf_mode ~dyn_mode ~dur_relation ~low ~high
          ~selection_principle states0
  in
  resolve_times protos

let zip5 a b c d e =
  List.map2 (fun (x, y) (z, (w, v)) -> (x, y, z, w, v)) (List.combine a b) (List.combine c (List.combine d e))

let generate_score_hierarchical ~variant_duration ~instrument_ensemble
    ~instrument_principle ~entry_delay_ensemble ~entry_delay_principle
    ~perf_ensemble ~perf_principle ~perf_mode ~dyn_ensemble ~dyn_principle
    ~dyn_mode ~dur_ensemble ~dur_principle ~dur_relation ~union ~hierarchy
    ~density =
  match union with
  | Union ->
      let entr_arr = ensemble_values_union entry_delay_ensemble in
      let instr_arr = ensemble_values_union instrument_ensemble in
      let perf_arr = ensemble_values_union perf_ensemble in
      let dyn_arr = ensemble_values_union dyn_ensemble in
      let dur_arr = ensemble_values_union dur_ensemble in
      let n_events =
        calculate_number_of_events variant_duration entry_delay_principle entr_arr
      in
      let _ = Printf.printf "estimated events: %d\n" n_events in
      [
        calculate_layer_hierarchical ~n_events ~hierarchy ~instr_arr
          ~instr_principle:instrument_principle ~ed_arr:entr_arr
          ~ed_principle:entry_delay_principle ~perf_arr ~perf_principle ~perf_mode
          ~dyn_arr ~dyn_principle ~dyn_mode ~dur_arr ~dur_principle ~dur_relation
          ~density;
      ]
  | NoUnion ->
      let instr_arrays = ensemble_values_no_union instrument_ensemble in
      let broadcast raw =
        match raw with
        | [ single ] -> List.init (List.length instr_arrays) (fun _ -> single)
        | _ -> raw
      in
      let entr_arrays = broadcast (ensemble_values_no_union entry_delay_ensemble) in
      let perf_arrays = broadcast (ensemble_values_no_union perf_ensemble) in
      let dyn_arrays = broadcast (ensemble_values_no_union dyn_ensemble) in
      let dur_arrays = broadcast (ensemble_values_no_union dur_ensemble) in
      zip5 instr_arrays entr_arrays perf_arrays dyn_arrays dur_arrays
      |> List.map (fun (instr_arr, entr_arr, perf_arr, dyn_arr, dur_arr) ->
          let n_events =
            calculate_number_of_events variant_duration entry_delay_principle entr_arr
          in
          let _ = Printf.printf "\nestimated events: %d " n_events in
          calculate_layer_hierarchical ~n_events ~hierarchy ~instr_arr
            ~instr_principle:instrument_principle ~ed_arr:entr_arr
            ~ed_principle:entry_delay_principle ~perf_arr ~perf_principle ~perf_mode
            ~dyn_arr ~dyn_principle ~dyn_mode ~dur_arr ~dur_principle ~dur_relation
            ~density)

let build_score cfg =
  Random.init cfg.seed;
  let instr_to_string (Instrument { instrument = InstrumentName n; _ }) = n in
  let ed_to_string (Entrydelay f) = Printf.sprintf "%.3f" f in
  let dur_to_string (Duration f) = Printf.sprintf "%.3f" f in
  let instr_ensemble =
    construct_ensemble ~label:"instrument" ~to_string:instr_to_string
      cfg.instr_list cfg.instr_table EnsembleGroupSeries
      cfg.number_of_instrument_groups
  in
  let ed_ensemble =
    match cfg.entrydelay_combination with
    | Combination ->
        construct_ensemble_combination ~label:"entrydelay"
          ~to_string:ed_to_string cfg.ed_list cfg.ed_table instr_ensemble
    | NoCombination ->
        construct_ensemble ~label:"entrydelay" ~to_string:ed_to_string
          cfg.ed_list cfg.ed_table EnsembleGroupSeries 1
  in
  let perf_list = cfg.perf_list in
  let dyn_list = cfg.dyn_list in
  let perf_ensemble =
    match cfg.performance_combination with
    | Combination ->
        construct_ensemble_combination ~label:"performance"
          ~to_string:Performance.to_string perf_list cfg.performance_table
          instr_ensemble
    | NoCombination ->
        construct_ensemble ~label:"performance" ~to_string:Performance.to_string
          perf_list cfg.performance_table EnsembleGroupSeries 1
  in
  let dyn_ensemble =
    match cfg.dynamics_combination with
    | Combination ->
        construct_ensemble_combination ~label:"dynamics"
          ~to_string:Dynamic.to_string dyn_list cfg.dynamics_table
          instr_ensemble
    | NoCombination ->
        construct_ensemble ~label:"dynamics" ~to_string:Dynamic.to_string
          dyn_list cfg.dynamics_table EnsembleGroupSeries 1
  in
  let dur_ensemble =
    match cfg.duration_combination with
    | Combination ->
        construct_ensemble_combination ~label:"duration" ~to_string:dur_to_string
          cfg.dur_list cfg.dur_table instr_ensemble
    | NoCombination ->
        construct_ensemble ~label:"duration" ~to_string:dur_to_string cfg.dur_list
          cfg.dur_table EnsembleGroupSeries 1
  in
  generate_score_hierarchical ~variant_duration:cfg.variant_duration
    ~instrument_ensemble:instr_ensemble
    ~instrument_principle:cfg.instrument_principle
    ~entry_delay_ensemble:ed_ensemble
    ~entry_delay_principle:cfg.entrydelay_principle ~perf_ensemble
    ~perf_principle:cfg.performance_principle ~perf_mode:cfg.performance_mode
    ~dyn_ensemble ~dyn_principle:cfg.dynamics_principle
    ~dyn_mode:cfg.dynamics_mode ~dur_ensemble
    ~dur_principle:cfg.duration_principle
    ~dur_relation:cfg.duration_relation_mode ~union:cfg.union
    ~hierarchy:cfg.hierarchy ~density:cfg.density

let build_constraint_map instrs =
  List.map
    (fun (Instrument { instrument; performance; dynamics; durations; _ }) ->
      (instrument, (performance, dynamics, durations)))
    instrs

(* Describe what, if anything, is wrong with a note's performance/dynamic/
   duration given the instrument's allowed modes and duration range. Empty
   list means the note is fine. *)
let note_problems constraint_map (note : note) =
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
          [ Printf.sprintf "duration %.3f could not satisfy the entry-delay relation (no valid candidate existed)" d ]
      in
      perf_problem @ dyn_problem @ dur_problem @ dur_relation_problem

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

let note_cells (note : note) =
  let (InstrumentName name) = note.instrument in
  let (Duration d) = note.duration in
  [
    Printf.sprintf "%.3f" note.time;
    Printf.sprintf "%.3f" note.entrydelay;
    Printf.sprintf "%.3f" d;
    name;
    Performance.to_string note.performance;
    Dynamic.to_string note.dynamic;
  ]

let note_header = [ "time"; "entrydelay"; "duration"; "instrument"; "performance"; "dynamic" ]

(* Flat view: one row per note (a multi-note chord produces several rows
   sharing the same time), ignoring entry grouping entirely. *)
let write_notes_score filename instrs layers =
  let constraint_map = build_constraint_map instrs in
  let all_rows =
    note_header
    :: (layers
       |> List.concat_map (fun entries ->
           entries |> List.concat_map (fun e -> e.notes) |> List.map note_cells))
  in
  let widths = Table.column_widths all_rows in
  let oc = open_out filename in
  List.iteri
    (fun i entries ->
      Printf.fprintf oc "# layer %d\n" i;
      entries
      |> List.iter (fun e ->
          e.notes
          |> List.iter (fun note ->
              Printf.fprintf oc "%s" (Table.render_row widths (note_cells note));
              (match note_problems constraint_map note with
              | [] -> ()
              | problems ->
                  Printf.fprintf oc " # IMPOSSIBLE: %s" (String.concat ", " problems));
              Printf.fprintf oc "\n")))
    layers;
  close_out oc

(* Hierarchical view: one header line per entry (time, instrument, note
   count, and whichever of performance/dynamic/duration were chord-wide),
   followed by its notes indented underneath. *)
let write_entries_score filename instrs layers =
  let constraint_map = build_constraint_map instrs in
  let opt_to_string to_string = function Some v -> to_string v | None -> "-" in
  let entry_cells (e : entry) =
    let (InstrumentName name) = e.instrument in
    [
      Printf.sprintf "%.3f" e.time;
      Printf.sprintf "%.3f" e.entrydelay;
      opt_to_string (fun (Duration d) -> Printf.sprintf "%.3f" d) e.duration;
      name;
      string_of_int (List.length e.notes);
      opt_to_string Performance.to_string e.performance;
      opt_to_string Dynamic.to_string e.dynamic;
    ]
  in
  let entry_header = [ "time"; "entrydelay"; "duration"; "instrument"; "notes"; "performance"; "dynamic" ] in
  let all_entry_rows = entry_header :: (layers |> List.concat_map (List.map entry_cells)) in
  let entry_widths = Table.column_widths all_entry_rows in
  let all_note_rows = note_header :: (layers |> List.concat_map (List.concat_map (fun e -> e.notes)) |> List.map note_cells) in
  let note_widths = Table.column_widths all_note_rows in
  let oc = open_out filename in
  List.iteri
    (fun i entries ->
      Printf.fprintf oc "# layer %d\n" i;
      entries
      |> List.iter (fun e ->
          Printf.fprintf oc "%s\n" (Table.render_row entry_widths (entry_cells e));
          e.notes
          |> List.iter (fun note ->
              Printf.fprintf oc "    %s" (Table.render_row note_widths (note_cells note));
              (match note_problems constraint_map note with
              | [] -> ()
              | problems ->
                  Printf.fprintf oc " # IMPOSSIBLE: %s" (String.concat ", " problems));
              Printf.fprintf oc "\n")))
    layers;
  close_out oc

let print_layers instrs layers =
  let constraint_map = build_constraint_map instrs in
  let total_violations = ref 0 in
  print_endline "\n=== instrument_entry_test ===";
  List.iteri
    (fun i entries ->
      Printf.printf "\n--- layer %d ---\n" i;
      Printf.printf "%-8s %-10s %-8s %-14s %-5s %-12s %-8s %s\n" "time" "entrydelay"
        "duration" "instrument" "notes" "performance" "dynamic" "status";
      entries
      |> List.iter (fun (e : entry) ->
          let (InstrumentName name) = e.instrument in
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
              Printf.printf "%-8.3f %-10.3f %-8.3f %-14s %-5d %-12s %-8s %s\n" note.time
                note.entrydelay d name (List.length e.notes)
                (Performance.to_string note.performance)
                (Dynamic.to_string note.dynamic)
                status)))
    layers;
  print_endline "";
  if !total_violations = 0 then
    print_endline "OK: every performance, dynamic and duration is valid for its instrument"
  else
    Printf.printf "VIOLATIONS: %d note(s) have invalid performance/dynamic/duration\n"
      !total_violations
