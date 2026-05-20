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

type selection_principle =
  | Alea (* random choice with possible repetition *)
  | Series (* random choice but exhaust all other options before repetition *)
  | Ratio of (int * int) list (* weighted choice, repetition allowed *)
  | Group of group_spec
    (* controlled repetition, various selection options for element and its repetitions *)
  | Tendency of tendency_mask_spec
  | Sequence of int list (* user defined order, looped *)

type 'a selection_result = Value of 'a | Impossible of 'a

let get_value sr = match sr with Value v -> v | Impossible v -> v

type 'e series_state = SeriesState of { initial : 'e list; options : 'e list }

type 'e sequence_state =
  | SequenceState of { initial : 'e list; options : 'e list }

let series_init (arr : 'a array) : 'a series_state =
  let initial = Array.to_list arr in
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

let to_seq stream = Seq.unfold (fun s -> Some (stream s))

(* ── Alea ── *)
type 'a alea_state = AleaState of 'a array

let filter_alea f (AleaState array) =
  AleaState (array |> Array.to_list |> List.filter f |> Array.of_list)

let alea_init arr = AleaState arr

let alea_draw (AleaState arr) =
  (Value arr.(Random.int (Array.length arr)), AleaState arr)

(* ── Ratio ── *)
type 'a ratio_state = RatioState of ('a * int) list

let ratio_init weighted = RatioState weighted

let ratio_draw (RatioState weighted) =
  let total = List.fold_left (fun acc (_, w) -> acc + w) 0 weighted in
  let r = Random.int total in
  let rec pick n = function
    | [] -> failwith "ratio_draw: empty"
    | [ (x, _) ] -> x
    | (x, w) :: rest -> if n < w then x else pick (n - w) rest
  in
  (Value (pick r weighted), RatioState weighted)

(* ── Sequence ── *)

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
type 'a group_element_state = GEAlea of 'a array | GESeries of 'a series_state
type group_rep_state = GRAlea of int * int | GRSeries of int series_state

type 'a group_state =
  | GroupState of {
      current : 'a;
      remaining : int;
      elem_state : 'a group_element_state;
      rep_state : group_rep_state;
    }

let group_pick_elem = function
  | GEAlea arr ->
      let v = arr.(Random.int (Array.length arr)) in
      (v, GEAlea arr)
  | GESeries s ->
      let r, s' = series_draw s in
      (get_value r, GESeries s')

let group_pick_rep = function
  | GRAlea (lo, hi) -> (lo + Random.int (hi - lo + 1), GRAlea (lo, hi))
  | GRSeries s ->
      let r, s' = series_draw s in
      (get_value r, GRSeries s')

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
    { current = first_elem; remaining = first_rep; elem_state; rep_state }

let group_draw (GroupState { current; remaining; elem_state; rep_state }) =
  let value = Value current in
  if remaining > 1 then
    ( value,
      GroupState { current; remaining = remaining - 1; elem_state; rep_state }
    )
  else
    let elem, elem_state' = group_pick_elem elem_state in
    let rep, rep_state' = group_pick_rep rep_state in
    ( value,
      GroupState
        {
          current = elem;
          remaining = rep;
          elem_state = elem_state';
          rep_state = rep_state';
        } )
