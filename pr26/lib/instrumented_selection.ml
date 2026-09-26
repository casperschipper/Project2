(* A thin, instrumented layer over [Selection]'s six selection principles:
   [sel_state] wraps whichever principle's own state is in play behind one
   type, and [sel_draw]/[sel_sample]/[sel_draw_pred_tagged]/
   [sel_sample_pred_tagged]/[sel_sample_pred] are the single primitives
   every draw in [Score_generation] goes through - each one optionally
   reports what it did to [Debug_log] (SERIES/RATIO pool exhaustion, a new
   GROUP repetition starting, a TENDENCY window) when given a [~ctx],
   costing nothing when it isn't. There is deliberately no separate
   "_debug"-suffixed twin of any of these to remember to call - see
   "manuals and notes/analysis of score generation module.md"'s section on
   debug mode for why that used to exist and why it doesn't now. *)

open Parameters
open Selection
open Tools

(* ---- Pure stateful selection principles state  ---- *)
(* [sel_state] wraps the per-principle state, explicit to avoid mutation *)
type 'a sel_state =
  | SAlea of 'a alea_state
  | SSeries of 'a series_state
  | SRatio of 'a ratio_state
  | SGroup of 'a group_state
  | STendency of 'a tendency_state
  | SSequence of 'a sequence_state

(* [arr] carries each element's original LIST index alongside its value, so
   that [Ratio]'s weights (declared per LIST index, see [ratio_weight_of])
   can be applied to whatever actually made it into this ensemble.
*)
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

(* Debug log context
  - SERIES/RATIO exhausting their pool and reshuffling
   (visible as [pre]'s [options] being empty), GROUP starting a new
   repetition (GROUP's own new element/repetition-count only exists in
   [post]
   - see [Selection.group_draw]: the "new group" fact is baked into
   the *returned* state, one call late), and, for TENDENCY, the window this
   draw sampled from. *)
let emit_sel_events ~(ctx : Debug_log.context) ~(to_string : 'a -> string)
    (pre : 'a sel_state) (post : 'a sel_state) =
  if !Debug_log.enabled then
    match pre with
    | SSeries (SeriesState { options = []; _ }) ->
        Debug_log.push (Debug_log.SeriesRestart ctx)
    | SRatio (RatioState { options = []; _ }) ->
        Debug_log.push (Debug_log.RatioRefresh ctx)
    | SGroup (GroupState { remaining = 1; _ }) -> (
        match post with
        | SGroup (GroupState { current; remaining; _ }) ->
            Debug_log.push
              (Debug_log.GroupNewRep
                 { ctx; element = to_string current; size = remaining })
        | _ -> ())
    | SGroup (GroupState { remaining = _; _ }) -> ()
    | STendency (TendencyState { arr = _; lo; hi; _ }) ->
        Debug_log.push (Debug_log.TendencyWindow { ctx; lo; hi })
    | SAlea _ | SSequence _ | SSeries _ | SRatio _ -> ()

(* Every draw goes through exactly one of these primitives - there is no
   separate "_debug" twin to remember to call, so no call site can silently
   omit instrumentation by picking the wrong one of a pair. [ctx] is
   optional only because a couple of call sites (see [sel_draw_n], used by
   [expected_value]'s own estimate) run before any entry/layer/variant
   context exists at all; every real hierarchy-resolution draw always has
   one and always passes it. Passing [ctx] costs nothing when
   [Debug_log.enabled] is [false] - the same short-circuit [Debug_log.emit]
   already relies on. *)
let sel_draw ?ctx ?(to_string = fun _ -> "") (state : 'a sel_state) :
    'a * 'a sel_state =
  let result, state' =
    match state with
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
  in
  (match ctx with
  | Some ctx -> emit_sel_events ~ctx ~to_string state state'
  | None -> ());
  (result, state')

(* Tagged variant of a predicate-conditioned draw: callers that need to know
   whether the hierarchy's constraint could actually be satisfied (e.g. to
   flag an "impossible" duration in the score) can inspect the
   [selection_result] tag; callers that don't care just [get_value] it. *)
let sel_draw_pred_tagged ?ctx ?(to_string = fun _ -> "") (p : 'a -> bool)
    (state : 'a sel_state) : 'a selection_result * 'a sel_state =
  let result, state' =
    match state with
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
        (* Sample from the predicate-filtered array within the current
           window, then advance the state to the next window position. *)
        let (TendencyState { arr; lo; hi; _ }) = s in
        let filtered =
          arr |> Array.to_list |> List.filter p |> Array.of_list
        in
        let v =
          if Array.length filtered = 0 then
            Impossible (tendency_sample arr lo hi)
          else Value (tendency_sample filtered lo hi)
        in
        let _, s' = tendency_draw s in
        (v, STendency s')
    | SSequence s ->
        (* Sequence has no predicate mechanism; advance freely. *)
        let v, s' = sequence_draw s in
        (v, SSequence s')
  in
  (match ctx with
  | Some ctx -> emit_sel_events ~ctx ~to_string state state'
  | None -> ());
  (result, state')

let sel_draw_pred ?ctx ?to_string (p : 'a -> bool) (state : 'a sel_state) :
    'a * 'a sel_state =
  let v, state' = sel_draw_pred_tagged ?ctx ?to_string p state in
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
let sel_sample ?ctx ?(to_string = fun _ -> "") (state : 'a sel_state) :
    'a * 'a sel_state =
  match state with
  | STendency (TendencyState { arr; lo; hi; _ } as s) ->
      let result = tendency_sample arr lo hi in
      (match ctx with
      | Some ctx -> emit_sel_events ~ctx ~to_string state (STendency s)
      | None -> ());
      (result, STendency s)
  | st -> sel_draw ?ctx ~to_string st

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
let sel_sample_pred_tagged ?ctx ?(to_string = fun _ -> "") (p : 'a -> bool)
    (state : 'a sel_state) : 'a selection_result * 'a sel_state =
  match state with
  | STendency (TendencyState { arr; lo; hi; _ } as s) ->
      let filtered = arr |> Array.to_list |> List.filter p |> Array.of_list in
      let v =
        if Array.length filtered = 0 then Impossible (tendency_sample arr lo hi)
        else Value (tendency_sample filtered lo hi)
      in
      (match ctx with
      | Some ctx -> emit_sel_events ~ctx ~to_string state (STendency s)
      | None -> ());
      (v, STendency s)
  | st -> sel_draw_pred_tagged ?ctx ~to_string p st

let sel_sample_pred ?ctx ?to_string (p : 'a -> bool) (state : 'a sel_state) :
    'a * 'a sel_state =
  let v, state' = sel_sample_pred_tagged ?ctx ?to_string p state in
  (get_value v, state')

let result_ok = function Value _ -> true | Impossible _ -> false
