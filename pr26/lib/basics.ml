open Tools


(* as we are indexing the table groups, we use arrays *)
type ptable =
  Table of int Array.t Array.t

type instr =
  Instrument of string

type entrydelay = 
  Entrydelay of float

type _ value = 
  | Inst : instr -> instr value
  | Entry : entrydelay -> entrydelay value

  (* we keep indexes that produced a value from the list, they may be useful *)
type 'a element =
  { index : int
  ; value : 'a value }

type 'a group = 
  'a element Array.t

type 'a parameter_list =
  ParameterList of 'a element Array.t


(* an ensemble is a list of groups, we keep the group structure, as they may still be used as separate layers *)
type 'a ensemble =
  Ensemble of ('a group list)

let of_nested_list lstlst = 
  lstlst |> List.map Array.of_list |> Array.of_list |>  fun x -> Table x

  

  

type chordsize =
  Chordsize of { minsize : int ; maxsize : int }


(* chordsize is min and max *)
let chordsize mini maxi = 
  Chordsize { minsize = min mini maxi; maxsize = max mini maxi}

(* a table is an array of arrays *)

type instrument = 
  Instrument of { name : string ; chordsize : chordsize }

let inst name chordsize = 
  Instrument { name = name; chordsize = chordsize }

(* test materials *)


type tendency_section =
  TendencySection of {
    portion    : float;
    start_min : UnitFloat.t;
    start_max : UnitFloat.t;
    end_min   : UnitFloat.t;
    end_max   : UnitFloat.t;
  } 



let section_sq n (TendencySection s) =
  Seq.init n (fun i ->
    let t = if n <= 1 then 0.0 else Float.of_int i /. Float.of_int (n - 1) in
    let lo = lerp (s.start_min :> float) (s.end_min :> float) t in
    let hi = lerp (s.start_max :> float) (s.end_max :> float) t in
    let lo, hi = if lo <= hi then lo, hi else hi, lo in
    lo +. Random.float (hi -. lo))
 
let tendency_mask_raw count sections =
  (* output between zero and one *)
  let portions = List.map (fun (TendencySection s) -> s.portion) sections in
  let total   = List.fold_left ( +. ) 0.0 portions in
  let exact   = List.map (fun w -> w /. total *. Float.of_int count) portions in
  (* largest remainder method for integer allocation *)
  let floors  = List.map (fun x -> int_of_float (floor x)) exact in
  let fracs   = List.map2 (fun x f -> x -. Float.of_int f) exact floors in
  let allocated = List.fold_left ( + ) 0 floors in
  let remainder = count - allocated in
  (* distribute remainder to sections with largest fractional parts *)
  let indexed = List.mapi (fun i f -> (i, f)) fracs in
  let sorted  = List.sort (fun (_, a) (_, b) -> Float.compare b a) indexed in
  let bonus_arr = Array.make (List.length sections) 0 in
  List.iteri (fun rank (orig_i, _) ->
    if rank < remainder then bonus_arr.(orig_i) <- 1) sorted;
  let counts  = List.mapi (fun i f -> f + bonus_arr.(i)) floors in
  List.map2 section_sq counts sections |> List.to_seq |> Seq.concat

let tendency_mask  ensemble count sections = 
  let l = Array.length ensemble in
  let index arr i = arr.(i) in
  tendency_mask_raw count sections |> Seq.map (fun x -> x *. (float_of_int l) |> floor |> int_of_float |> index ensemble) 


  (* For the group selection principle both group size and amount of reps is controlled by Alea or Series *)
type group_selection =
  | GroupAlea
  | GroupSeries

  (* for formation of the ensemble Alea, Series or Sequence will pick the groups from the table *)
type ensemble_group_selection = 
  | EnsembleGroupAlea
  | EnsembleGroupSeries
  | EnsembleGroupSequence

type group_spec =
  GroupSpec of { element :group_selection ;repetition : group_selection; min_rep : int ; max_rep : int }

type selection_principle =
  | Alea (* random choice with possible repetition *)
  | Series (* random choice but exhaust all other options before repetition *)
  | Ratio of int list (* weighted choice, possible repetition *)
  | Group of group_spec (* controlled repetition, various selection options for element and its repetitions *)
  | Tendency of tendency_section list
  | Sequence of int list (* user defined order, looped *)

let mkGroup elm rep min_rep max_rep = 
  let mi = min min_rep max_rep in
  let ma = max min_rep max_rep in
  GroupSpec { element = elm ; repetition = rep ; min_rep = mi ; max_rep = ma }


let alea_sq ensemble = 
  let n = Array.length ensemble in
  let f () = Some (ensemble.(Random.int n), ()) in
  Seq.unfold f ()

let series_select start = 
  let shuffled () = shuffle start |> Array.to_list in
  let f remain =
    match remain with
    | [] -> (match shuffled () with 
      | x::xs -> Some (x,xs)
      | [] -> None)
    | x::xs -> Some (x, xs)
  in
  Seq.unfold f (shuffled ())

let series_sq n = 
  let start = List.init n id |> Array.of_list in
  series_select start

let  ch_series lst = 
  let arr = lst |> Array.of_list in
  let n = Array.length arr in
  series_sq n |> Seq.map (fun i -> arr.(i))


let ratio_sq lst =
  let start = lst |> List.concat_map (fun (x,n) -> repeat x n) |> Array.of_list in
  series_select start

let sequence lst = 
  Seq.cycle (List.to_seq lst)

let random_value a b = 
  let range = abs (b - a) in
  let mini = min a b in 
  mini + Random.int range 



let group_sq ensemble (GroupSpec { element  ;repetition ; min_rep  ; max_rep  }) = 
  match (element, repetition) with
  | (GroupAlea, GroupAlea) -> 
    choose ensemble |> Seq.concat_map (fun elm -> repeat_n elm (random_value min_rep max_rep))
  | (GroupSeries, GroupAlea) -> 
    ch_series ensemble |> Seq.concat_map (fun elm -> repeat_n elm (random_value min_rep max_rep))
  | (GroupSeries, GroupSeries) -> 
    (let elms = ch_series ensemble in
    let reps = ch_series (range min_rep max_rep) in
    Seq.map2 repeat_n elms reps |> Seq.concat )
  | (GroupAlea, GroupSeries) ->  
    (let elms = choose ensemble in
    let reps = ch_series (range min_rep max_rep) in
    Seq.map2 repeat_n elms reps |> Seq.concat)

let contruct_ensemble table principle max_number_of_groups =
  match principle with
  | EnsembleGroupAlea -> 
  | EnsembleGroupSeries -> 
  | EnsembleGroupSequence seq -> 

let expected_value selection_principle ensemble =
  (* calculates the expected (average) value produced by the selection principle over the ensemble *)
  let array_average arr =
    let sum = Array.fold_left ( +. ) 0.0 arr in
    sum /. Float.of_int (Array.length arr)
  in
  match selection_principle with
  | Alea -> array_average ensemble
  | Series -> array_average ensemble
  | Ratio ratios ->
    (* ratios are weights parallel to ensemble elements *)
    let pairs = List.combine (Array.to_list ensemble) ratios in
    let weighted_sum = List.fold_left (fun acc (v, w) -> acc +. v *. (float_of_int w)) 0.0 pairs in
    let total_weight = List.fold_left ( + ) 0 ratios in
    weighted_sum /. (Float.of_int total_weight)
  | Group _group_spec ->
    (* element selection is uniform over the ensemble regardless of group/rep mode *)
    array_average ensemble
  | Tendency sections ->
    let n_samples = 1000 in
    let values = tendency_mask ensemble n_samples sections |> List.of_seq in
    let sum = List.fold_left ( +. ) 0.0 values in
    sum /. Float.of_int (List.length values)
  | Sequence seq ->
    seq |> List.map (fun i -> ensemble.(i)) |> List.fold_left ( +. ) 0.0 |> fun sum -> sum /. (float_of_int (List.length seq))