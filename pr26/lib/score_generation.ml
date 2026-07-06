open Parameters
open Structure_formula
open Selection
open Tools

(* Proto event used during hierarchical score generation. Each field
   starts empty and is filled in as the hierarchy is applied; entrydelay
   is filled up front since it does not depend on hierarchy order, and
   nr_of_tones is filled when the score is built. *)
type proto_event =
  | Proto of {
      entrydelay : entrydelay option;
      instrument : instrument option;
      nr_of_tones : int option;
      performance : Performance.t option;
      dynamic : Dynamic.t option;
    }

let empty_proto =
  Proto
    {
      entrydelay = None;
      instrument = None;
      nr_of_tones = None;
      performance = None;
      dynamic = None;
    }

type score_event = {
  time : float;
  instrument : instr;
  chordsize : int;
  performance : Performance.t;
  dynamic : Dynamic.t;
}

(* Extract all values from any ensemble as a flat array *)
let ensemble_values_union ensemble =
  match ensemble with
  | Ensemble groups ->
      groups
      |> List.map elements_from_indexed_ensemble
      |> Array.concat
      |> Array.map value_from_element
  | SingleGroup elm ->
      elm |> elements_from_indexed_ensemble |> Array.map value_from_element

let ensemble_values_no_union ensemble =
  match ensemble with
  | Ensemble groups ->
      groups
      |> List.map (fun x ->
          x |> elements_from_indexed_ensemble |> Array.map value_from_element)
  | SingleGroup g ->
      g |> elements_from_indexed_ensemble |> Array.map value_from_element
      |> fun x -> [ x ]

(* do the combination case *)
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

let sel_init (principle : selection_principle) (n : int) (arr : 'a array) :
    'a sel_state =
  match principle with
  | Alea -> SAlea (alea_init arr)
  | Series -> SSeries (series_init arr)
  | Ratio rs ->
      SRatio (ratio_init (List.map (fun (i, cnt) -> (arr.(i), cnt)) rs))
  | Group gs -> SGroup (group_init arr gs)
  | Tendency spec -> STendency (tendency_init ~count:n arr spec)
  | Sequence indices ->
      SSequence (sequence_init (List.map (fun i -> arr.(i)) indices))

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

let sel_draw_pred (p : 'a -> bool) : 'a sel_state -> 'a * 'a sel_state =
  function
  | SAlea s ->
      let v, s' = alea_draw_predicate p s in
      (get_value v, SAlea s')
  | SSeries s ->
      let v, s' = series_draw_predicate p s in
      (get_value v, SSeries s')
  | SRatio s ->
      let v, s' = ratio_draw_predicate p s in
      (get_value v, SRatio s')
  | SGroup s ->
      let v, s' = group_draw_predicate p s in
      (get_value v, SGroup s')
  | STendency s ->
      (* Sample from the predicate-filtered array within the current window,
         then advance the state to the next window position. *)
      let (TendencyState { arr; lo; hi; _ }) = s in
      let filtered = arr |> Array.to_list |> List.filter p |> Array.of_list in
      let v =
        if Array.length filtered = 0 then tendency_sample arr lo hi
        else tendency_sample filtered lo hi
      in
      let _, s' = tendency_draw s in
      (v, STendency s')
  | SSequence s ->
      (* Sequence has no predicate mechanism; advance freely. *)
      let v, s' = sequence_draw s in
      (get_value v, SSequence s')

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
   instruments for autonomous density) while only moving each tendency mask's
   window once per timepoint, via a single later [sel_advance_window] call. *)
let sel_sample_pred (p : 'a -> bool) : 'a sel_state -> 'a * 'a sel_state =
  function
  | STendency (TendencyState { arr; lo; hi; _ } as s) ->
      let filtered = arr |> Array.to_list |> List.filter p |> Array.of_list in
      let v =
        if Array.length filtered = 0 then tendency_sample arr lo hi
        else tendency_sample filtered lo hi
      in
      (v, STendency s)
  | st -> sel_draw_pred p st

let calculate_number_of_events variant_duration entry_delay_principle
    entry_delay_ensemble =
  let avg_ed = expected_value entry_delay_principle entry_delay_ensemble in
  int_of_float (floor (variant_duration /. avg_ed))

(* ---- Hierarchical layer calculation ---- *)

(* States threaded through the hierarchy fold — one per parameter hierarchy controls.
   [instr_arr] is kept here so the Per step can constrain itself to performances
   achievable by at least one instrument in this group, even before Ins runs. *)
type layer_states = {
  instr_state : instrument sel_state;
  perf_state : Performance.t sel_state;
  dyn_state : Dynamic.t sel_state;
  instr_arr : instrument array;
}

(* One step of the hierarchy fold.
   [protos] is the list being built up; [states] carries the selector states.
   Returns updated [(protos, states)] with one more field filled per event.

   Conditioning rules:
   - Ins step: restrict to instruments whose modes include the already-chosen
     performance (if Per ran) and whose dynamics include the already-chosen
     dynamic (if Dyn ran).
   - Per step: if Ins already ran (instrument is set), restrict to that
     instrument's modes; if Ins has not run yet, restrict to performances
     achievable by at least one instrument in this group, so that when Ins
     runs next it can always find a compatible match.
   - Dyn step: same as Per, but for the instrument's allowed dynamics. *)
let apply_step (protos, states) (elem : hierarchy_elem) =
  match elem with
  | Ins ->
      let instr_state', filled =
        List.fold_left_map
          (fun st (Proto pe) ->
            let perf_pred =
              match pe.performance with
              | None -> Fun.const true
              | Some perf ->
                  fun (Instrument { performance = modes; _ }) ->
                    Performance_modes.mem perf modes
            in
            let dyn_pred =
              match pe.dynamic with
              | None -> Fun.const true
              | Some dyn ->
                  fun (Instrument { dynamics = modes; _ }) ->
                    Dynamic_modes.mem dyn modes
            in
            let pred i = perf_pred i && dyn_pred i in
            let v, st' = sel_draw_pred pred st in
            (st', Proto { pe with instrument = Some v }))
          states.instr_state protos
      in
      (filled, { states with instr_state = instr_state' })
  | Per ->
      let perf_state', filled =
        List.fold_left_map
          (fun st (Proto pe) ->
            let pred =
              match pe.instrument with
              | Some (Instrument { performance = modes; _ }) ->
                  fun p -> Performance_modes.mem p modes
              | None ->
                  fun p ->
                    Array.exists
                      (fun (Instrument { performance = modes; _ }) ->
                        Performance_modes.mem p modes)
                      states.instr_arr
            in
            let v, st' = sel_draw_pred pred st in
            (st', Proto { pe with performance = Some v }))
          states.perf_state protos
      in
      (filled, { states with perf_state = perf_state' })
  | Dyn ->
      let dyn_state', filled =
        List.fold_left_map
          (fun st (Proto pe) ->
            let pred =
              match pe.instrument with
              | Some (Instrument { dynamics = modes; _ }) ->
                  fun d -> Dynamic_modes.mem d modes
              | None ->
                  fun d ->
                    Array.exists
                      (fun (Instrument { dynamics = modes; _ }) ->
                        Dynamic_modes.mem d modes)
                      states.instr_arr
            in
            let v, st' = sel_draw_pred pred st in
            (st', Proto { pe with dynamic = Some v }))
          states.dyn_state protos
      in
      (filled, { states with dyn_state = dyn_state' })

(* Combine filled protos into score events. Entry delays accumulate
   left-to-right to produce absolute times.
   Pure: time is threaded as a fold accumulator, no refs. *)
let protos_to_events (protos : proto_event list) : score_event list =
  let _, events =
    List.fold_left
      (fun (t, acc) (Proto pe) ->
        let ed =
          match pe.entrydelay with Some (Entrydelay ed) -> ed | None -> 0.0
        in
        let event =
          match (pe.instrument, pe.performance, pe.dynamic) with
          | ( Some
                (Instrument
                   { instrument; chordsize = Chordsize { minsize; maxsize }; _ }),
              Some performance,
              Some dynamic ) ->
              let chordsize =
                match pe.nr_of_tones with
                | Some n -> n
                | None ->
                    if minsize = maxsize then minsize
                    else Random.int (maxsize - minsize + 1) + minsize
              in
              Some { time = t; instrument; chordsize; performance; dynamic }
          | _ -> None
        in
        (t +. ed, match event with Some e -> e :: acc | None -> acc))
      (0.0, []) protos
  in
  List.rev events

(* Fill in performance/dynamic for one already-instrument-picked proto,
   conditioned on that instrument, in the relative order [Per]/[Dyn] appear in
   [per_dyn_order] (their order doesn't affect each other's outcome, only
   which selector state advances first). Uses [sel_sample_pred] rather than
   [sel_draw_pred] so a tendency mask's window is not moved yet — several of
   these calls may happen within the same timepoint. *)
let fill_conditioned_performance_dynamic per_dyn_order states instr proto =
  List.fold_left
    (fun (Proto pe, states) elem ->
      match elem with
      | Per ->
          let (Instrument { performance = modes; _ }) = instr in
          let pred p = Performance_modes.mem p modes in
          let v, st' = sel_sample_pred pred states.perf_state in
          (Proto { pe with performance = Some v }, { states with perf_state = st' })
      | Dyn ->
          let (Instrument { dynamics = modes; _ }) = instr in
          let pred d = Dynamic_modes.mem d modes in
          let v, st' = sel_sample_pred pred states.dyn_state in
          (Proto { pe with dynamic = Some v }, { states with dyn_state = st' })
      | Ins -> (Proto pe, states))
    (proto, states) per_dyn_order

(* Autonomous density keeps picking instruments (each with its own randomly
   chosen chordsize, drawn from that instrument's own min/max) until the
   sampled [target] density is reached or exceeded — overshooting on the last
   pick is fine. Every instrument picked this way starts a full proto event
   (with its own performance/dynamic, conditioned on it), all sharing the same
   timepoint. Returns the protos for this timepoint (oldest first) and the
   selector states advanced by one sample per pick. *)
let fill_autonomous_timepoint per_dyn_order states target =
  let rec loop states total acc =
    let instr, instr_state' =
      sel_sample_pred (Fun.const true) states.instr_state
    in
    let (Instrument { chordsize = Chordsize { minsize; maxsize }; _ }) =
      instr
    in
    let chordsize =
      if minsize = maxsize then minsize
      else Random.int (maxsize - minsize + 1) + minsize
    in
    let states = { states with instr_state = instr_state' } in
    let (Proto p) = empty_proto in
    let base =
      Proto { p with instrument = Some instr; nr_of_tones = Some chordsize }
    in
    let proto, states =
      fill_conditioned_performance_dynamic per_dyn_order states instr base
    in
    let total' = total + chordsize in
    let acc' = proto :: acc in
    if total' >= target then (List.rev acc', states)
    else loop states total' acc'
  in
  loop states 0 []

(* All protos in a timepoint group share the same start time: only the last
   one carries the entrydelay to the next timepoint, the rest carry a 0.0
   entrydelay so [protos_to_events]'s running time doesn't move between them. *)
let stamp_group_entrydelay group ed =
  let n = List.length group in
  List.mapi
    (fun i (Proto pe) ->
      let delay = if i = n - 1 then ed else 0.0 in
      Proto { pe with entrydelay = Some (Entrydelay delay) })
    group

let advance_all_windows states =
  {
    states with
    instr_state = sel_advance_window states.instr_state;
    perf_state = sel_advance_window states.perf_state;
    dyn_state = sel_advance_window states.dyn_state;
  }

(** Calculate one layer using the hierarchy list. Entry delays are always
    computed first (independent of hierarchy order) and stored on each proto up
    front. The hierarchy then specifies the order in which [Ins] and [Per] are
    filled, where later steps can condition on earlier ones.

    With [InstrumentDensity], each timepoint is exactly one event and its
    chordsize comes from the picked instrument's own range (as usual).
    With [Autonomous], each timepoint samples a target density and keeps
    adding instruments (see [fill_autonomous_timepoint]) until it is reached;
    all of them start at the timepoint's shared time. *)
let calculate_layer_hierarchical ~n_events ~hierarchy ~instr_arr
    ~instr_principle ~ed_arr ~ed_principle ~perf_arr ~perf_principle ~dyn_arr
    ~dyn_principle ~density =
  let eds =
    sel_draw_n n_events ed_principle ed_arr |> List.map entry_to_float
  in
  let init_states =
    {
      instr_state = sel_init instr_principle n_events instr_arr;
      perf_state = sel_init perf_principle n_events perf_arr;
      dyn_state = sel_init dyn_principle n_events dyn_arr;
      instr_arr;
    }
  in
  match density with
  | InstrumentDensity ->
      let protos =
        List.map
          (fun ed ->
            let (Proto p) = empty_proto in
            Proto { p with entrydelay = Some (Entrydelay ed) })
          eds
      in
      let filled, _ =
        List.fold_left apply_step (protos, init_states) hierarchy
      in
      protos_to_events filled
  | Autonomous { low; high; selection_principle } ->
      let dens_arr = Array.init (high - low + 1) (fun i -> low + i) in
      let per_dyn_order = hierarchy |> List.filter (fun e -> e <> Ins) in
      let _, _, groups =
        List.fold_left
          (fun (states, dens_state, acc) ed ->
            let target, dens_state' = sel_sample dens_state in
            let group, states' =
              fill_autonomous_timepoint per_dyn_order states target
            in
            (advance_all_windows states', sel_advance_window dens_state', stamp_group_entrydelay group ed :: acc))
          (init_states, sel_init selection_principle n_events dens_arr, [])
          eds
      in
      groups |> List.rev |> List.concat |> protos_to_events

let generate_score_hierarchical ~variant_duration ~instrument_ensemble
    ~instrument_principle ~entry_delay_ensemble ~entry_delay_principle
    ~perf_ensemble ~perf_principle ~dyn_ensemble ~dyn_principle ~union
    ~hierarchy ~density =
  match union with
  | Union ->
      let entr_arr = ensemble_values_union entry_delay_ensemble in
      let instr_arr = ensemble_values_union instrument_ensemble in
      let perf_arr = ensemble_values_union perf_ensemble in
      let dyn_arr = ensemble_values_union dyn_ensemble in
      let n_events =
        calculate_number_of_events variant_duration entry_delay_principle
          entr_arr
      in
      let _ = Printf.printf "estimated events: %d\n" n_events in
      [
        calculate_layer_hierarchical ~n_events ~hierarchy ~instr_arr
          ~instr_principle:instrument_principle ~ed_arr:entr_arr
          ~ed_principle:entry_delay_principle ~perf_arr ~perf_principle ~dyn_arr
          ~dyn_principle ~density;
      ]
  | NoUnion ->
      let instr_arrays = ensemble_values_no_union instrument_ensemble in
      let broadcast raw =
        match raw with
        | [ single ] -> List.init (List.length instr_arrays) (fun _ -> single)
        | _ -> raw
      in
      let entr_arrays =
        broadcast (ensemble_values_no_union entry_delay_ensemble)
      in
      let perf_arrays = broadcast (ensemble_values_no_union perf_ensemble) in
      let dyn_arrays = broadcast (ensemble_values_no_union dyn_ensemble) in
      let zip4 a b c d =
        List.map2
          (fun (x, y) (z, w) -> (x, y, z, w))
          (List.combine a b) (List.combine c d)
      in
      zip4 instr_arrays entr_arrays perf_arrays dyn_arrays
      |> List.map (fun (instr_arr, entr_arr, perf_arr, dyn_arr) ->
          let n_events =
            calculate_number_of_events variant_duration entry_delay_principle
              entr_arr
          in
          let _ = Printf.printf "\nestimated events: %d " n_events in
          calculate_layer_hierarchical ~n_events ~hierarchy ~instr_arr
            ~instr_principle:instrument_principle ~ed_arr:entr_arr
            ~ed_principle:entry_delay_principle ~perf_arr ~perf_principle
            ~dyn_arr ~dyn_principle ~density)

let build_score cfg =
  let instr_to_string (Instrument { instrument = InstrumentName n; _ }) = n in
  let ed_to_string (Entrydelay f) = Printf.sprintf "%.3f" f in
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
  let (ParameterList instr_list) = cfg.instr_list in
  let perf_list =
    extract_performances_from_instruments (Array.to_list instr_list)
  in
  let dyn_list = extract_dynamics_from_instruments (Array.to_list instr_list) in
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
  generate_score_hierarchical ~variant_duration:cfg.variant_duration
    ~instrument_ensemble:instr_ensemble
    ~instrument_principle:cfg.instrument_principle
    ~entry_delay_ensemble:ed_ensemble
    ~entry_delay_principle:cfg.entrydelay_principle ~perf_ensemble
    ~perf_principle:cfg.performance_principle ~dyn_ensemble
    ~dyn_principle:cfg.dynamics_principle ~union:cfg.union
    ~hierarchy:cfg.hierarchy ~density:cfg.density

let build_constraint_map instrs =
  List.map
    (fun (Instrument { instrument; performance; dynamics; _ }) ->
      (instrument, (performance, dynamics)))
    instrs

(* Describe what, if anything, is wrong with an event's performance/dynamic
   given the instrument's allowed modes. Empty list means the event is fine. *)
let event_problems constraint_map event =
  match List.assoc_opt event.instrument constraint_map with
  | None -> [ "unknown instrument" ]
  | Some (valid_perfs, valid_dyns) ->
      let perf_ok = Performance_modes.mem event.performance valid_perfs in
      let dyn_ok = Dynamic_modes.mem event.dynamic valid_dyns in
      let perf_problem =
        if perf_ok then []
        else
          let valid_perfs_str =
            Performance_modes.elements valid_perfs
            |> List.map Performance.to_string
            |> String.concat ", "
          in
          [
            Printf.sprintf "performance '%s' (valid: %s)"
              (Performance.to_string event.performance)
              valid_perfs_str;
          ]
      in
      let dyn_problem =
        if dyn_ok then []
        else
          let valid_dyns_str =
            Dynamic_modes.elements valid_dyns
            |> List.map Dynamic.to_string |> String.concat ", "
          in
          [
            Printf.sprintf "dynamic '%s' (valid: %s)"
              (Dynamic.to_string event.dynamic)
              valid_dyns_str;
          ]
      in
      perf_problem @ dyn_problem

let write_score filename layers =
  let oc = open_out filename in
  List.iteri
    (fun i events ->
      Printf.fprintf oc "# layer %d\n" i;
      List.iter
        (fun { time; instrument = InstrumentName name; chordsize; performance;
               dynamic } ->
          Printf.fprintf oc "%.3f %s %d %s %s\n" time name chordsize
            (Performance.to_string performance)
            (Dynamic.to_string dynamic))
        events)
    layers;
  close_out oc

let print_layers instrs layers =
  let constraint_map = build_constraint_map instrs in
  let total_violations = ref 0 in
  print_endline "\n=== instrument_entry_test ===";
  List.iteri
    (fun i events ->
      Printf.printf "\n--- layer %d ---\n" i;
      Printf.printf "%-8s %-14s %-5s %-12s %-8s %s\n" "time" "instrument" "cs"
        "performance" "dynamic" "status";
      List.iter
        (fun ({
                time;
                instrument = InstrumentName name;
                chordsize;
                performance;
                dynamic;
              } as event) ->
          let problems = event_problems constraint_map event in
          let status =
            match problems with
            | [] -> ""
            | ps ->
                incr total_violations;
                "!! IMPOSSIBLE: " ^ String.concat ", " ps
          in
          Printf.printf "%-8.3f %-14s %-5d %-12s %-8s %s\n" time name chordsize
            (Performance.to_string performance)
            (Dynamic.to_string dynamic)
            status)
        events)
    layers;
  print_endline "";
  if !total_violations = 0 then
    print_endline
      "OK: every performance and dynamic is valid for its instrument"
  else
    Printf.printf "VIOLATIONS: %d event(s) have invalid performance/dynamic\n"
      !total_violations
