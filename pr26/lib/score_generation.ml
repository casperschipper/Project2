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
  (* [true] iff this note's instrument had already been picked earlier within
     the same autonomous-density chord - i.e. there weren't enough distinct
     instruments to "score" the chord without reusing one (EMR-3 8.16). *)
  instrument_repeated : bool;
}

(* One timepoint: the entry delay is resolved exactly once here, for the
   whole chord, never per note. Under [InstrumentDensity] a chord is always
   one instrument's worth of notes; under [Autonomous] density it may be
   "scored" from several instruments (EMR-3 8.16's "sub-chords... put
   together"), so [notes] isn't restricted to a single instrument.
   [instrument]/[performance]/[dynamic]/[duration] are [Some] only when every
   note in the entry actually agrees on that value - not a resolution-time
   tag, just a display convenience computed from the final [notes]. *)
type entry = {
  time : float;
  entrydelay : float;
  notes : note list;
  instrument : instr option;
  performance : Performance.t option;
  dynamic : Dynamic.t option;
  duration : duration option;
  (* see [note.instrument_repeated] - true if any note in this entry is. *)
  instrument_repeated : bool;
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

(* In-progress entry while the hierarchy fold runs: everything starts [None]
   and gets filled in hierarchy order. [nr_of_notes] is filled as soon as
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
  let values, _oks, state' = resolve_note_param_tagged mode n_notes pred state in
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
    | Some (PerNote ps) -> List.for_all (fun p -> Performance_modes.mem p modes) ps
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
            dur_pred_from ~instr_arr:states.instr_arr proto dur_relation (Duration ed)
          in
          let v, ed_state' = sel_sample_pred_tagged pred states.ed_state in
          let ok = result_ok v in
          ( { states with ed_state = ed_state' },
            { proto with entrydelay = Some (get_value v); duration_ok = Some (Shared ok) } )
      | _ ->
          let pred = ed_pred_from proto dur_relation in
          let v, ed_state' = sel_sample_pred pred states.ed_state in
          ({ states with ed_state = ed_state' }, { proto with entrydelay = Some v }))
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
              duration_ok = Some (Option.value proto.duration_ok ~default:(Shared true));
            } )
      | _ ->
          let mode = duration_note_mode dur_relation in
          let pred = dur_pred_from ~instr_arr:states.instr_arr proto dur_relation in
          let v, oks, dur_state' =
            resolve_note_param_tagged mode proto.nr_of_notes pred states.dur_state
          in
          ( { states with dur_state = dur_state' },
            { proto with duration = Some v; duration_ok = Some oks } ))
  | Per ->
      let pred =
        mode_pred_from_instrument ~instr_arr:states.instr_arr ~mem:Performance_modes.mem
          proto.instrument
          (fun (Instrument { performance; _ }) -> performance)
      in
      let v, perf_state' = resolve_note_param perf_mode proto.nr_of_notes pred states.perf_state in
      ({ states with perf_state = perf_state' }, { proto with performance = Some v })
  | Dyn ->
      let pred =
        mode_pred_from_instrument ~instr_arr:states.instr_arr ~mem:Dynamic_modes.mem
          proto.instrument
          (fun (Instrument { dynamics; _ }) -> dynamics)
      in
      let v, dyn_state' = resolve_note_param dyn_mode proto.nr_of_notes pred states.dyn_state in
      ({ states with dyn_state = dyn_state' }, { proto with dynamic = Some v })

let resolve_entry ?(start = empty_proto) ~hierarchy ~perf_mode ~dyn_mode ~dur_relation states =
  List.fold_left (resolve_step ~perf_mode ~dyn_mode ~dur_relation) (states, start) hierarchy

(** With [InstrumentDensity], every entry is its own timepoint - one
    instrument, one already-resolved entry delay. Each is wrapped as a
    singleton group so step 2 can treat both density modes uniformly. *)
let resolve_layer_instrument_density ~n_events ~hierarchy ~perf_mode ~dyn_mode
    ~dur_relation states0 =
  let _, groups =
    List.init n_events (fun _ -> ())
    |> List.fold_left
         (fun (states, acc) () ->
           let states', proto = resolve_entry ~hierarchy ~perf_mode ~dyn_mode ~dur_relation states in
           let ed = match proto.entrydelay with Some ed -> ed | None -> Entrydelay 0.0 in
           (advance_all_windows states', (ed, [ proto ]) :: acc))
         (states0, [])
  in
  List.rev groups

(** With [Autonomous] density, each timepoint samples a target density and
    keeps resolving sub-picks (each independently picking its own instrument,
    conditioned the same way as any other) until the target is reached. If
    the last pick's chordsize would overshoot the target, its extra voices
    are cut - [nr_of_notes] is capped down to however many are still needed,
    so the group's total lands exactly on the target. (Any per-note
    performance/dynamic/duration values already drawn for the trimmed voices
    are simply never read.)

    Unlike [InstrumentDensity], a timepoint here may need several sub-picks
    to "score" the chord (EMR-3 8.16), and the whole chord shares exactly one
    entry delay - so [Ent] is deliberately excluded from each sub-pick's own
    hierarchy fold ([hierarchy_no_ent]) and resolved once per group instead,
    positioned relative to the sub-pick loop by wherever the composer put
    [Ent] relative to [Dur] in [hierarchy]. This preserves both possible
    conditioning directions via the exact same predicates [resolve_step]
    already uses for a single sub-pick ([dur_pred_from]/[ed_pred_from]) -
    just fed a value that's fixed for the whole group instead of one proto:
    - [Ent] before [Dur]: the group's entry delay is drawn once, up front,
      and every sub-pick's [Dur] step conditions on it exactly as it would if
      [Ent] had run first for that one sub-pick (seeded via [resolve_entry]'s
      [~start], never drawn again).
    - [Dur] before [Ent]: every sub-pick's [Dur] resolves unconstrained (no
      entry delay exists yet), and the group's entry delay is drawn once
      *after* the loop, either unconstrained ([DurIndependent]) or bounded by
      the longest duration seen anywhere in the group ([DurShorterThanEntry]
      - generalizing [ed_pred_from]'s own per-proto max-over-per-note-values
      check to a max over the whole group). [DurEqualsEntry] is the one
      relation where this ordering still settles the shared value mid-loop:
      the first sub-pick's freely-drawn duration *becomes* the group's entry
      delay, and every later sub-pick is then forced to copy it (mirroring
      the original single-sub-pick "[Dur] before [Ent]" case, just decided
      once for the whole chord instead of once per sub-pick). *)
let resolve_layer_autonomous ~n_events ~hierarchy ~perf_mode ~dyn_mode
    ~dur_relation ~low ~high ~selection_principle states0 =
  let dens_arr = Array.init (high - low + 1) (fun i -> low + i) |> elements_of_array in
  let hierarchy_no_ent = List.filter (fun e -> e <> Ent) hierarchy in
  let ent_before_dur =
    let index_of x =
      let rec go i = function
        | [] -> assert false (* hierarchy is always a permutation of all 5 elems - see mk_hierarchy *)
        | y :: rest -> if y = x then i else go (i + 1) rest
      in
      go 0 hierarchy
    in
    index_of Ent < index_of Dur
  in
  let resolve_subpick ?seed_entrydelay states =
    let start =
      match seed_entrydelay with
      | Some ed -> { empty_proto with entrydelay = Some ed }
      | None -> empty_proto
    in
    resolve_entry ~start ~hierarchy:hierarchy_no_ent ~perf_mode ~dyn_mode ~dur_relation states
  in
  let max_duration_of proto =
    match proto.duration with
    | Some (Shared (Duration d)) -> d
    | Some (PerNote ds) -> ds |> List.map (fun (Duration d) -> d) |> List.fold_left Float.max 0.0
    | None -> 0.0
  in
  let force_not_ok = function Shared _ -> Shared false | PerNote xs -> PerNote (List.map (fun _ -> false) xs) in
  (* Overrides [duration_ok] group-wide: used when the group's one shared
     entry delay itself turned out [Impossible], a chord-level fact that
     can't be pinned on any single sub-pick's own (otherwise-fine) draw. *)
  let mark_group_ok ok proto =
    if ok then proto else { proto with duration_ok = Option.map force_not_ok proto.duration_ok }
  in
  let stamp_ok ok proto = { proto with duration_ok = Some (Shared ok) } in
  (* Resolves the sub-picks that fill one chord to [target]. [seed] is the
     entry delay already fixed for the whole group (if any) before the first
     sub-pick runs; [next_seed] derives what becomes fixed for the *next*
     sub-pick from what's fixed so far and the sub-pick just resolved - used
     only by [DurEqualsEntry]'s "settle from the first sub-pick" case below,
     a no-op everywhere else. *)
  let fill_subpicks states target ~seed ~next_seed =
    (* [used] carries every instrument already picked earlier in this same
       chord, so a later pick that lands on one of them - the orchestra
       running out of distinct instruments before the target density is
       reached - can be flagged (EMR-3 8.16: "the programme expects there to
       be enough instruments ... If there are not enough instruments, each
       repeated instrument is provided with a comment"). *)
    let rec loop states total used acc settled =
      let states', proto = resolve_subpick ?seed_entrydelay:settled states in
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
        let proto' = { proto with nr_of_notes = Some (n - (total' - target)) } in
        (settled', List.rev (proto' :: acc), states')
      else loop states' total' used' (proto :: acc) settled'
    in
    loop states 0 [] [] seed
  in
  let keep_seed settled _ = settled in
  let fill_group states target =
    match (dur_relation, ent_before_dur) with
    | DurEqualsEntry, true ->
        (* the drawn value becomes every sub-pick's duration verbatim (below),
           so - exactly like the single-sub-pick case this generalizes - it
           must itself be achievable as *some* instrument's duration. *)
        let pred (Entrydelay ed) = dur_pred_from ~instr_arr:states.instr_arr empty_proto dur_relation (Duration ed) in
        let v, ed_state' = sel_sample_pred_tagged pred states.ed_state in
        let ok = result_ok v in
        let ed = get_value v in
        let states = { states with ed_state = ed_state' } in
        let _, group, states' = fill_subpicks states target ~seed:(Some ed) ~next_seed:keep_seed in
        (ed, List.map (stamp_ok ok) group, states')
    | DurEqualsEntry, false ->
        let next_seed settled proto =
          match settled with
          | Some _ -> settled
          | None -> ( match proto.duration with Some (Shared (Duration d)) -> Some (Entrydelay d) | _ -> None)
        in
        let settled, group, states' = fill_subpicks states target ~seed:None ~next_seed in
        (* [duration_note_mode DurEqualsEntry] is always [PerChord], so the
           first sub-pick always settles [settled] to [Some _] via [next_seed]
           above - this can't stay [None]. *)
        let ed = Option.get settled in
        let ok =
          match group with
          | p :: _ -> ( match p.duration_ok with Some (Shared ok) -> ok | _ -> true)
          | [] -> true
        in
        (ed, List.map (stamp_ok ok) group, states')
    | (DurIndependent _ | DurShorterThanEntry _), true ->
        let v, ed_state' = sel_sample_pred_tagged (Fun.const true) states.ed_state in
        let ed = get_value v in
        let states = { states with ed_state = ed_state' } in
        let _, group, states' = fill_subpicks states target ~seed:(Some ed) ~next_seed:keep_seed in
        (ed, group, states')
    | (DurIndependent _ | DurShorterThanEntry _), false ->
        let _, group, states' = fill_subpicks states target ~seed:None ~next_seed:keep_seed in
        let max_dur = group |> List.fold_left (fun acc p -> Float.max acc (max_duration_of p)) 0.0 in
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
  let _, _, groups =
    List.init n_events (fun _ -> ())
    |> List.fold_left
         (fun (states, dens_state, acc) () ->
           let target, dens_state' = sel_sample dens_state in
           let ed, group, states' = fill_group states target in
           (advance_all_windows states', sel_advance_window dens_state', (ed, group) :: acc))
         (states0, sel_init selection_principle n_events dens_arr, [])
  in
  List.rev groups

(* ---- Step 2: turn resolved protos into the final score (entries + notes) ---- *)

(* One sub-pick's own notes - no entry delay or time here yet, both are a
   property of the whole entry (see [entry_of_group]), not of one sub-pick. *)
let notes_of_proto proto : note list =
  let instr = match proto.instrument with Some (Instrument { instrument; _ }) -> instrument | None -> assert false in
  let n = Option.value proto.nr_of_notes ~default:1 in
  let perf = match proto.performance with Some tv -> tv | None -> assert false in
  let dyn = match proto.dynamic with Some tv -> tv | None -> assert false in
  let dur = match proto.duration with Some tv -> tv | None -> assert false in
  let dur_ok = match proto.duration_ok with Some tv -> tv | None -> assert false in
  List.init n (fun i ->
      {
        time = 0.0;
        instrument = instr;
        performance = value_at perf i;
        dynamic = value_at dyn i;
        duration = value_at dur i;
        duration_ok = value_at dur_ok i;
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
    protos |> List.concat_map notes_of_proto |> List.map (fun (n : note) -> { n with time })
  in
  {
    time;
    entrydelay = ed;
    notes;
    instrument = uniform_value (fun (n : note) -> n.instrument) notes;
    performance = uniform_value (fun (n : note) -> n.performance) notes;
    dynamic = uniform_value (fun (n : note) -> n.dynamic) notes;
    duration = uniform_value (fun (n : note) -> n.duration) notes;
    instrument_repeated = List.exists (fun (n : note) -> n.instrument_repeated) notes;
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
  let groups =
    match density with
    | InstrumentDensity ->
        resolve_layer_instrument_density ~n_events ~hierarchy ~perf_mode ~dyn_mode ~dur_relation states0
    | Autonomous { low; high; selection_principle } ->
        resolve_layer_autonomous ~n_events ~hierarchy ~perf_mode ~dyn_mode ~dur_relation ~low ~high
          ~selection_principle states0
  in
  resolve_times groups

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
    | NoCombination sel ->
        construct_ensemble ~label:"entrydelay" ~to_string:ed_to_string
          cfg.ed_list cfg.ed_table sel 1
  in
  let perf_list = cfg.perf_list in
  let dyn_list = cfg.dyn_list in
  let perf_ensemble =
    match cfg.performance_combination with
    | Combination ->
        construct_ensemble_combination ~label:"performance"
          ~to_string:Performance.to_string perf_list cfg.performance_table
          instr_ensemble
    | NoCombination sel ->
        construct_ensemble ~label:"performance" ~to_string:Performance.to_string
          perf_list cfg.performance_table sel 1
  in
  let dyn_ensemble =
    match cfg.dynamics_combination with
    | Combination ->
        construct_ensemble_combination ~label:"dynamics"
          ~to_string:Dynamic.to_string dyn_list cfg.dynamics_table
          instr_ensemble
    | NoCombination sel ->
        construct_ensemble ~label:"dynamics" ~to_string:Dynamic.to_string
          dyn_list cfg.dynamics_table sel 1
  in
  let dur_ensemble =
    match cfg.duration_combination with
    | Combination ->
        construct_ensemble_combination ~label:"duration" ~to_string:dur_to_string
          cfg.dur_list cfg.dur_table instr_ensemble
    | NoCombination sel ->
        construct_ensemble ~label:"duration" ~to_string:dur_to_string cfg.dur_list
          cfg.dur_table sel 1
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
let instrument_repeated_problem (note : note) =
  if note.instrument_repeated then
    [ "instrument reused within this chord (not enough distinct instruments to reach the vertical density)" ]
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
  ]

let note_header = [ "time"; "entrydelay"; "duration"; "instrument"; "performance"; "dynamic" ]

(* Flat view: one row per note (a multi-note chord produces several rows
   sharing the same time), ignoring entry grouping entirely. *)
let opt_to_string to_string = function Some v -> to_string v | None -> "-"

let instrument_name_opt = opt_to_string (fun (InstrumentName n) -> n)

let cells_for_entry_notes (e : entry) = List.map (fun (n : note) -> note_cells ~entrydelay:e.entrydelay n) e.notes

let write_notes_score filename instrs (layers : entry list list) =
  let constraint_map = build_constraint_map instrs in
  let all_rows =
    note_header :: (layers |> List.concat_map (List.concat_map cells_for_entry_notes))
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
              Printf.fprintf oc "%s" (Table.render_row widths (note_cells ~entrydelay:e.entrydelay note));
              (match note_problems constraint_map note with
              | [] -> ()
              | problems ->
                  Printf.fprintf oc " # IMPOSSIBLE: %s" (String.concat ", " problems));
              Printf.fprintf oc "\n")))
    layers;
  close_out oc

(* Hierarchical view: one header line per entry (time, instrument, note
   count, and whichever of performance/dynamic/duration were chord-wide),
   followed by its notes indented underneath. [instrument] is "-" when an
   entry's notes span more than one instrument (EMR-3 8.16 "scoring"). *)
let write_entries_score filename instrs (layers : entry list list) =
  let constraint_map = build_constraint_map instrs in
  let entry_cells (e : entry) =
    [
      Printf.sprintf "%.3f" e.time;
      Printf.sprintf "%.3f" e.entrydelay;
      opt_to_string (fun (Duration d) -> Printf.sprintf "%.3f" d) e.duration;
      instrument_name_opt e.instrument;
      string_of_int (List.length e.notes);
      opt_to_string Performance.to_string e.performance;
      opt_to_string Dynamic.to_string e.dynamic;
    ]
  in
  let entry_header = [ "time"; "entrydelay"; "duration"; "instrument"; "notes"; "performance"; "dynamic" ] in
  let all_entry_rows = entry_header :: (layers |> List.concat_map (List.map entry_cells)) in
  let entry_widths = Table.column_widths all_entry_rows in
  let all_note_rows = note_header :: (layers |> List.concat_map (List.concat_map cells_for_entry_notes)) in
  let note_widths = Table.column_widths all_note_rows in
  let oc = open_out filename in
  List.iteri
    (fun i (entries : entry list) ->
      Printf.fprintf oc "# layer %d\n" i;
      entries
      |> List.iter (fun (e : entry) ->
          Printf.fprintf oc "%s\n" (Table.render_row entry_widths (entry_cells e));
          e.notes
          |> List.iter (fun note ->
              Printf.fprintf oc "    %s" (Table.render_row note_widths (note_cells ~entrydelay:e.entrydelay note));
              (match note_problems constraint_map note with
              | [] -> ()
              | problems ->
                  Printf.fprintf oc " # IMPOSSIBLE: %s" (String.concat ", " problems));
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
      Printf.printf "%-8s %-10s %-8s %-14s %-5s %-12s %-8s %s\n" "time" "entrydelay"
        "duration" "instrument" "notes" "performance" "dynamic" "status";
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
              Printf.printf "%-8.3f %-10.3f %-8.3f %-14s %-5d %-12s %-8s %s\n" note.time
                e.entrydelay d name (List.length e.notes)
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
