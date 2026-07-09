open Tools

type ('s, 'a) selector_stream = 's -> 'a * 's
type group_selection = GroupAlea | GroupSeries

type group_spec =
  | GroupSpec of {
      element : group_selection;
      repetition : group_selection;
      min_rep : int;
      max_rep : int;
    }

(* For the group selection principle both group size and amount of reps is controlled by Alea or Series *)
type tendency_section =
  | TendencySection of {
      portion : float;
      start_min : UnitFloat.t;
      start_max : UnitFloat.t;
      end_min : UnitFloat.t;
      end_max : UnitFloat.t;
    }

type tendency_mask_spec = TendencyMask of tendency_section list

(* 
  The main sum type representing which method (and what parameters) we are using for selection from the ensemble
*)
type selection_principle =
  | Alea (* random choice with possible repetition *)
  | Series (* random choice but exhaust all other options before repetition *)
  | Ratio of (int * int) list (* weighted choice, repetition allowed *)
  | Group of group_spec
    (* controlled repetition, various selection options for element and its repetitions *)
  | Tendency of tendency_mask_spec
  | Sequence of int list (* user defined order, looped *)

(* A selection either results in a value, or in an impossible, 
where the hierarchy prevented picking a value *)
type 'a selection_result = Value of 'a | Impossible of 'a

let get_value sr = match sr with Value v -> v | Impossible v -> v

(* We do not use Seq.t, we explicitely define the state as a type, so we can handle when it is updated separately from when we draw values from it *)
type 'e series_state = SeriesState of { initial : 'e list; options : 'e list }

(* sequence is just the initial user chosen order and the current available options*)
type 'e sequence_state =
  | SequenceState of { initial : 'e list; options : 'e list }

(* Moses will return two lists, those that fit the predicate and those that dont.
This is useful when handling the hierarchy condition *)
let moses f lst =
  (* we expect small lists, so not worth doing fold_left *)
  List.fold_right
    (fun x (yes, no) -> if f x then (x :: yes, no) else (yes, x :: no))
    lst ([], [])

(* pick first item that qualifies pred, and returns the remaining options *)
let pick_first pred lst =
  let rec aux acc = function
    | [] -> (None, List.rev acc)
    | x :: rest ->
        if pred x then (Some x, List.rev acc @ rest) else aux (x :: acc) rest
  in
  aux [] lst

let series_init (arr : 'a array) : 'a series_state =
  (* sorted, basically a set of possibilities *)
  let initial = Array.to_list arr in
  (* shuffled *)
  let options = shuffle arr |> Array.to_list in
  SeriesState { initial; options }

let series_draw : 'a series_state -> 'a selection_result * 'a series_state =
 fun (SeriesState { initial; options }) ->
  let pick x xs = (Value x, SeriesState { initial; options = xs }) in
  match options with
  | x :: xs -> pick x xs
  | [] -> (
      match shuffle (Array.of_list initial) |> Array.to_list with
      | x :: xs -> pick x xs
      | [] -> failwith "series_draw: empty")

let series_draw_predicate p (SeriesState { initial; options }) =
  let pick x xs =
    (* we pick the first possible option *)
    match pick_first p (x :: xs) with
    | Some v, left -> (Value v, SeriesState { initial; options = left })
    (* no possible options, pick the first value, mark as impossible *)
    | None, left -> (Impossible x, SeriesState { initial; options = left })
  in
  match options with
  | x :: xs -> pick x xs
  | [] -> (
      match shuffle (Array.of_list initial) |> Array.to_list with
      | x :: xs -> pick x xs
      | [] -> failwith "series_draw: empty")

let to_seq stream = Seq.unfold (fun s -> Some (stream s))

(* ── Alea ── *)
(* ---------- *)
type 'a alea_state = AleaState of 'a array

let alea_init arr = AleaState arr

let alea_draw (AleaState arr) =
  (Value arr.(Random.int (Array.length arr)), AleaState arr)

let alea_draw_predicate p (AleaState arr) =
  let yes = arr |> Array.to_list |> List.filter p in
  match yes with
  | [] -> (Impossible arr.(Random.int (Array.length arr)), AleaState arr)
  | _ -> (Value (List.nth yes (Random.int (List.length yes))), AleaState arr)

(* ── Ratio ── *)
(* ---------- *)
type 'a ratio_state = RatioState of { initial : 'a list; options : 'a list }

let ratio_expand weighted =
  List.concat_map (fun (x, n) -> List.init n (fun _ -> x)) weighted

let ratio_init weighted =
  let initial = ratio_expand weighted in
  let options = shuffle (Array.of_list initial) |> Array.to_list in
  RatioState { initial; options }

let ratio_draw (RatioState { initial; options }) =
  (* note that for aestetic reasons, I have chosen a similarity to SERIES. 
      a ratio driven set of values is drawn up, that is shuffled consumed fully before renewed.
      It is not exactly a weighted choice, but with the predicate situation it is slightly better balanced. 
      Especially note predicate: even if we get blocked by hierarchy, the ratio will still be expressed pretty well, 
        but it will do its best "impossible" values when it can.
      @Question: might this produce more "impossible values" than necessary?
  *)
  let pick x xs = (Value x, RatioState { initial; options = xs }) in
  match options with
  | x :: xs -> pick x xs
  | [] -> (
      match shuffle (Array.of_list initial) |> Array.to_list with
      | x :: xs -> pick x xs
      | [] -> failwith "ratio_draw: empty")

let ratio_draw_predicate p (RatioState { initial; options }) =
  let pick x xs =
    (* we pick the first possible option *)
    match pick_first p (x :: xs) with
    | Some v, left -> (Value v, RatioState { initial; options = left })
    (* no possible options, pick the first value, mark impossible *)
    | None, left -> (Impossible x, RatioState { initial; options = left })
  in
  match options with
  | x :: xs -> pick x xs
  | [] -> (
      match shuffle (Array.of_list initial) |> Array.to_list with
      | x :: xs -> pick x xs
      | [] -> failwith "ratio_draw: empty")

(* ── Sequence ── *)
(* -------------- *)

(* TODO: protect empty list *)
let sequence_init (values : 'a list) =
  SequenceState { initial = values; options = values }

let sequence_draw (SequenceState { initial; options }) =
  match options with
  | x :: xs -> (Value x, SequenceState { initial; options = xs })
  | [] -> (
      match initial with
      | x :: xs -> (Value x, SequenceState { initial; options = xs })
      | [] -> failwith "sequence_draw: empty")

(* ── Group ── *)
type 'a group_elem_state = GEAlea of 'a array | GESeries of 'a series_state
type group_rep_state = GRAlea of int * int | GRSeries of int series_state

type 'a group_state =
  | GroupState of {
      current : 'a;
      remaining : int;
      elem_state : 'a group_elem_state;
      rep_state : group_rep_state;
    }

let group_pick_elem = function
  | GEAlea arr ->
      let v = arr.(Random.int (Array.length arr)) in
      (Value v, GEAlea arr)
  | GESeries s ->
      let r, s' = series_draw s in
      (r, GESeries s')

let group_pick_elem_pred p = function
  | GEAlea arr -> (
      let valid = arr |> Array.to_list |> List.filter p in
      match valid with
      | [] ->
          let v = arr.(Random.int (Array.length arr)) in
          (Impossible v, GEAlea arr)
      | _ ->
          let v = List.nth valid (Random.int (List.length valid)) in
          (Value v, GEAlea arr))
  | GESeries s ->
      let r, s' = series_draw_predicate p s in
      (r, GESeries s')

let group_pick_rep = function
  | GRAlea (lo, hi) -> (lo + Random.int (hi - lo + 1), GRAlea (lo, hi))
  | GRSeries s ->
      let r, s' = series_draw s in
      (get_value r, GRSeries s')

let mk_group_spec element repetition min_rep max_rep =
  GroupSpec { element; repetition; min_rep; max_rep }

let group_init arr (GroupSpec { element; repetition; min_rep; max_rep }) =
  let rep_range = Array.init (max_rep - min_rep + 1) (fun i -> i + min_rep) in
  let elem_state0 =
    match element with
    | GroupAlea -> GEAlea arr
    | GroupSeries -> GESeries (series_init arr)
  in
  let rep_state0 =
    match repetition with
    | GroupAlea -> GRAlea (min_rep, max_rep)
    | GroupSeries -> GRSeries (series_init rep_range)
  in
  let first_elem, elem_state = group_pick_elem elem_state0 in
  let first_rep, rep_state = group_pick_rep rep_state0 in
  GroupState
    {
      current = get_value first_elem;
      remaining = first_rep;
      elem_state;
      rep_state;
    }

let group_draw (GroupState { current; remaining; elem_state; rep_state }) =
  let value = Value current in
  if remaining > 1 then
    ( value,
      GroupState { current; remaining = remaining - 1; elem_state; rep_state }
    )
  else
    let next, elem_state' = group_pick_elem elem_state in
    let rep, rep_state' = group_pick_rep rep_state in
    ( value,
      GroupState
        {
          current = get_value next;
          remaining = rep;
          elem_state = elem_state';
          rep_state = rep_state';
        } )

(* Mid-repetition: predicate failure returns Impossible — no alternative can be chosen.
   At cycle boundary (remaining = 1): pick the next element with the predicate applied. *)
let group_draw_predicate p
    (GroupState { current; remaining; elem_state; rep_state }) =
  let result = if p current then Value current else Impossible current in
  if remaining > 1 then
    ( result,
      GroupState { current; remaining = remaining - 1; elem_state; rep_state }
    )
  else
    let next, elem_state' = group_pick_elem_pred p elem_state in
    let rep, rep_state' = group_pick_rep rep_state in
    ( result,
      GroupState
        {
          current = get_value next;
          remaining = rep;
          elem_state = elem_state';
          rep_state = rep_state';
        } )

(* ── Tendency ── *)

let tendency_counts count (TendencyMask sections) =
  let portions = List.map (fun (TendencySection s) -> s.portion) sections in
  let total = List.fold_left ( +. ) 0.0 portions in
  let exact = List.map (fun w -> w /. total *. Float.of_int count) portions in
  let floors = List.map (fun x -> int_of_float (floor x)) exact in
  let fracs = List.map2 (fun x f -> x -. Float.of_int f) exact floors in
  let allocated = List.fold_left ( + ) 0 floors in
  let remainder = count - allocated in
  let indexed = List.mapi (fun i f -> (i, f)) fracs in
  let sorted = List.sort (fun (_, a) (_, b) -> Float.compare b a) indexed in
  let bonus_arr = Array.make (List.length sections) 0 in
  List.iteri
    (fun rank (orig_i, _) -> if rank < remainder then bonus_arr.(orig_i) <- 1)
    sorted;
  List.mapi (fun i f -> f + bonus_arr.(i)) floors

let section_windows n (TendencySection s) : (float * float) Seq.t =
  Seq.init n (fun i ->
      let t = if n <= 1 then 0.0 else Float.of_int i /. Float.of_int (n - 1) in
      let lo = lerp (s.start_min :> float) (s.end_min :> float) t in
      let hi = lerp (s.start_max :> float) (s.end_max :> float) t in
      if lo <= hi then (lo, hi) else (hi, lo))

let tendency_windows count (spec : tendency_mask_spec) : (float * float) Seq.t =
  let (TendencyMask sections) = spec in
  let counts = tendency_counts count spec in
  List.map2 section_windows counts sections |> List.to_seq |> Seq.concat

type 'a tendency_state =
  | TendencyState of {
      arr : 'a array;
      spec : tendency_mask_spec;
      count : int;
      lo : float;
      hi : float;
      rest : (float * float) Seq.t;
    }

let tendency_sample arr lo hi =
  let l = Array.length arr in
  arr.(lo +. Random.float (hi -. lo)
       |> ( *. ) (float_of_int l)
       |> floor |> int_of_float)

let tendency_mk_state arr spec count =
  match Seq.uncons (tendency_windows count spec) with
  | None -> failwith "tendency_init: empty"
  | Some ((lo, hi), rest) -> TendencyState { arr; spec; count; lo; hi; rest }

let tendency_init ~count arr spec = tendency_mk_state arr spec count

let tendency_draw (TendencyState { arr; spec; count; lo; hi; rest }) =
  let value = Value (tendency_sample arr lo hi) in
  let state' =
    match Seq.uncons rest with
    | Some ((lo', hi'), rest') ->
        TendencyState { arr; spec; count; lo = lo'; hi = hi'; rest = rest' }
    | None -> tendency_mk_state arr spec count
  in
  (value, state')

(* Sample from the current window without advancing the mask position *)
let tendency_peek (TendencyState { arr; lo; hi; _ }) = tendency_sample arr lo hi

let tendency_draw_predicate p (TendencyState { arr; spec; count; _ }) =
  tendency_mk_state
    (arr |> Array.to_list |> List.filter p |> Array.of_list)
    spec count
