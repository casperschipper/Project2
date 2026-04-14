open Tools

(* as we are indexing the table groups, we use arrays of ints *)
type ptable = Table of int Array.t Array.t
type instr = Instrument of string
type entrydelay = Entrydelay of float

(* a value
type _ value =
  | Inst : instr -> instr value
  | Entry : entrydelay -> entrydelay value *)

let entry_to_float (Entrydelay x) = x
(* let value_to_float v = match v with Entry (Entrydelay x) -> x *)

let mk_instr str =
  match str with
  | "" -> raise (Failure "instrument cannot be empty string")
  | nonEmpty -> Instrument nonEmpty

let mk_entrydelay ed =
  if ed < 0.0 then raise (Failure "entrydelay cannot be smaller than zero ??")
  else Entrydelay ed

(* This is the full list of parameters *)
type 'a parameter_list = ParameterList of 'a Array.t

(* we keep indexes that produced a value from the list, they may be useful *)
type 'a element = { index : int; value : 'a }
type 'a group = EnsembleGroup of 'a element Array.t

let mk_par_list constructor lst =
  ParameterList (lst |> List.map constructor |> Array.of_list)

let lookup_index (ParameterList arr) i = arr.(i)

(* an ensemble is a list of groups, we keep the group structure, as they may still be used as separate layers *)
type 'a ensemble = Ensemble of 'a group list

let mk_ensemble group_list = Ensemble group_list

let of_nested_list lstlst =
  lstlst |> List.map Array.of_list |> Array.of_list |> fun x -> Table x

type chordsize = Chordsize of { minsize : int; maxsize : int }

(* chordsize is min and max *)
let chordsize mini maxi =
  Chordsize { minsize = min mini maxi; maxsize = max mini maxi }

(* a table is an array of arrays *)

type instrument = Instrument of { name : string; chordsize : chordsize }

let inst name chordsize = Instrument { name; chordsize }

(* test materials *)

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
type group_selection = GroupAlea | GroupSeries

(* for formation of the ensemble Alea, Series or Sequence will pick the groups from the table *)
type ensemble_group_selection =
  | EnsembleGroupAlea
  | EnsembleGroupSeries
  | EnsembleGroupSequence of int list

type group_spec =
  | GroupSpec of {
      element : group_selection;
      repetition : group_selection;
      min_rep : int;
      max_rep : int;
    }

type selection_principle =
  | Alea (* random choice with possible repetition *)
  | Series (* random choice but exhaust all other options before repetition *)
  | Ratio of (int * int) list (* weighted choice, repetition allowed *)
  | Group of group_spec
    (* controlled repetition, various selection options for element and its repetitions *)
  | Tendency of tendency_mask_spec
  | Sequence of int list (* user defined order, looped *)

let section_sq n (TendencySection s) =
  Seq.init n (fun i ->
      let t = if n <= 1 then 0.0 else Float.of_int i /. Float.of_int (n - 1) in
      let lo = lerp (s.start_min :> float) (s.end_min :> float) t in
      let hi = lerp (s.start_max :> float) (s.end_max :> float) t in
      let lo, hi = if lo <= hi then (lo, hi) else (hi, lo) in
      lo +. Random.float (hi -. lo))

let tendency_mask_raw count (TendencyMask sections) =
  (* Claude wrote this, still needs to be tested if it acts like we want *)
  (* output between zero and one *)
  let portions = List.map (fun (TendencySection s) -> s.portion) sections in
  let total = List.fold_left ( +. ) 0.0 portions in
  let exact = List.map (fun w -> w /. total *. Float.of_int count) portions in
  (* largest remainder method for integer allocation *)
  let floors = List.map (fun x -> int_of_float (floor x)) exact in
  let fracs = List.map2 (fun x f -> x -. Float.of_int f) exact floors in
  let allocated = List.fold_left ( + ) 0 floors in
  let remainder = count - allocated in
  (* distribute remainder to sections with largest fractional parts *)
  let indexed = List.mapi (fun i f -> (i, f)) fracs in
  let sorted = List.sort (fun (_, a) (_, b) -> Float.compare b a) indexed in
  let bonus_arr = Array.make (List.length sections) 0 in
  List.iteri
    (fun rank (orig_i, _) -> if rank < remainder then bonus_arr.(orig_i) <- 1)
    sorted;
  let counts = List.mapi (fun i f -> f + bonus_arr.(i)) floors in
  List.map2 section_sq counts sections |> List.to_seq |> Seq.concat

let tendency_mask count ensemble sections =
  let l = Array.length ensemble in
  let index arr i = arr.(i) in
  tendency_mask_raw count sections
  |> Seq.map (fun x ->
      x *. float_of_int l |> floor |> int_of_float |> index ensemble)

let group_selection_to_string gs =
  match gs with GroupAlea -> "alea" | GroupSeries -> "series"

let group_spec_to_string (GroupSpec { element; repetition; min_rep; max_rep }) =
  "group (elements:"
  ^ group_selection_to_string element
  ^ "), repetition:"
  ^ group_selection_to_string repetition
  ^ ")" ^ Int.to_string min_rep ^ "-" ^ Int.to_string max_rep ^ ")"

let tendency_to_string sections =
  let section_str (TendencySection s) =
    Printf.sprintf "%.2f:[%.2f-%.2f->%.2f-%.2f]" s.portion
      (s.start_min :> float)
      (s.start_max :> float)
      (s.end_min :> float)
      (s.end_max :> float)
  in
  "tendency(" ^ (sections |> List.map section_str |> String.concat " ") ^ ")"

let principle_to_string p =
  match p with
  | Alea -> "alea"
  | Series -> "series"
  | Ratio lst ->
      "ratio "
      ^ (lst
        |> List.map (fun t ->
            t |> tuple_map Int.to_string |> tuple_reduce ( ^ ))
        |> String.concat " ")
  | Group group_spec -> group_spec |> group_spec_to_string
  | Tendency (TendencyMask t) -> tendency_to_string t
  | Sequence ilst ->
      "sequence " ^ (ilst |> List.map Int.to_string |> String.concat " ")

let mkGroup elm rep min_rep max_rep =
  let mi = min min_rep max_rep in
  let ma = max min_rep max_rep in
  GroupSpec { element = elm; repetition = rep; min_rep = mi; max_rep = ma }

let alea_sq arr =
  let n = Array.length arr in
  let f () = Some (arr.(Random.int n), ()) in
  Seq.unfold f ()

let series_select start =
  let shuffled () = shuffle start |> Array.to_list in
  let f remain =
    match remain with
    | [] -> ( match shuffled () with x :: xs -> Some (x, xs) | [] -> None)
    | x :: xs -> Some (x, xs)
  in
  Seq.unfold f (shuffled ())

let series_sq n =
  let start = List.init n id |> Array.of_list in
  series_select start

let ch_series lst =
  let arr = lst |> Array.of_list in
  let n = Array.length arr in
  series_sq n |> Seq.map (fun i -> arr.(i))

let ratio_sq lst =
  let start =
    lst |> List.concat_map (fun (x, n) -> repeat x n) |> Array.of_list
  in
  series_select start

let sequence lst = Seq.cycle (List.to_seq lst)

let sequence_select arr lst =
  sequence lst |> Seq.map (fun i -> lookup_arr arr i)

let random_value a b =
  let range = abs (b - a) in
  let mini = min a b in
  mini + Random.int range

let group element repetition min_rep max_rep =
  Group (GroupSpec { element; repetition; min_rep; max_rep })

let group_sq ensemble (GroupSpec { element; repetition; min_rep; max_rep }) =
  match (element, repetition) with
  | GroupAlea, GroupAlea ->
      choose ensemble
      |> Seq.concat_map (fun elm -> repeat_n elm (random_value min_rep max_rep))
  | GroupSeries, GroupAlea ->
      ch_series ensemble
      |> Seq.concat_map (fun elm -> repeat_n elm (random_value min_rep max_rep))
  | GroupSeries, GroupSeries ->
      let elms = ch_series ensemble in
      let reps = ch_series (range min_rep max_rep) in
      Seq.map2 repeat_n elms reps |> Seq.concat
  | GroupAlea, GroupSeries ->
      let elms = choose ensemble in
      let reps = ch_series (range min_rep max_rep) in
      Seq.map2 repeat_n elms reps |> Seq.concat

(* ensemble formation *)

let group_from_indexes plist group =
  EnsembleGroup
    (group
    |> List.map (fun i -> { index = i; value = lookup_index plist i })
    |> Array.of_list)

(** [construct_ensemble parlist table principle number_of_groups] Builds an
    [ensemble] by selecting [number_of_groups] groups from [table].

    - [parlist] : the parameter list used to resolve indexes to values
    - [table] : an array of groups, where each group is an array of indexes into
      [parlist]
    - [principle] : how groups are drawn from the table:
    - [number_of_groups]: how many groups to include in the resulting ensemble

    Returns an [ensemble] whose groups contain fully resolved [element] values.
*)
let construct_ensemble parlist (Table table) principle number_of_groups =
  let select_groups grps =
    grps |> Seq.take number_of_groups |> Seq.map Array.to_list
    |> Seq.map (group_from_indexes parlist)
    |> List.of_seq |> mk_ensemble
  in
  match principle with
  | EnsembleGroupAlea -> alea_sq table |> select_groups
  | EnsembleGroupSeries -> series_select table |> select_groups
  | EnsembleGroupSequence sq ->
      sequence sq |> Seq.map (lookup_arr table) |> select_groups

let ensemble_to_array_union (Ensemble ensemble) =
  ensemble
  |> List.map (fun (EnsembleGroup eg) -> eg)
  |> Array.concat
  |> Array.map (fun { value; _ } -> value |> entry_to_float)

let expected_value selection_principle ensembles =
  let ensemble = ensembles |> ensemble_to_array_union in
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
      let pairs = ratios |> List.map (fun (i, w) -> (ensemble.(i), w)) in
      let weights = ratios |> List.map (fun (_, w) -> w) in
      let weighted_sum =
        List.fold_left
          (fun acc (v, w) -> acc +. (v *. float_of_int w))
          0.0 pairs
      in
      let total_weight = List.fold_left ( + ) 0 weights in
      weighted_sum /. float_of_int total_weight
  | Group _group_spec ->
      (* element selection is uniform over the ensemble regardless of group/rep mode *)
      array_average ensemble
  | Tendency sections ->
      let n_samples = 1000 in
      let values = tendency_mask n_samples ensemble sections |> List.of_seq in
      let sum = List.fold_left ( +. ) 0.0 values in
      sum /. Float.of_int (List.length values)
  | Sequence seq ->
      seq |> List.map (fun i -> ensemble.(i)) |> List.fold_left ( +. ) 0.0
      |> fun sum -> sum /. float_of_int (List.length seq)

type combination =
  | Combination (* index of combined parameters is the same as instrument *)
  | NoCombination
(* parameter selects their own group (independent of the groups indexes of instrument) *)

type union =
  | Union
  (* ensemble is a single unit, no layers *)
  | NoUnion
(* the number of layers is equal to the number of groups in the ensemble, the combined parameters also have same number of groups *)

(* ---- Score generation ---- *)

type score_event = { time : float; instrument : instrument; chordsize : int }

(* Extract all values from any ensemble as a flat array *)
let ensemble_values (Ensemble groups) =
  groups
  |> List.map (fun (EnsembleGroup g) -> g)
  |> Array.concat
  |> Array.map (fun { value; _ } -> value)

(** Build an infinite selection sequence from a principle and an array of
    values. Tendency is not yet supported (it requires a fixed total count). *)
let sel_seq_of_array n principle arr =
  match principle with
  | Alea -> alea_sq arr
  | Series -> series_select arr
  | Ratio ratios ->
      ratios
      |> List.concat_map (fun (i, n) -> repeat arr.(i) n)
      |> Array.of_list |> series_select
  | Group groupspec -> group_sq (Array.to_list arr) groupspec
  | Sequence indices -> sequence indices |> Seq.map (fun i -> arr.(i))
  | Tendency sections -> tendency_mask n arr sections

(** Generate a list of score events, using instrument based vertical density *)
let generate_score ~structure_duration ~instrument_ensemble
    ~instrument_principle ~entry_delay_ensemble ~entry_delay_principle =
  let avg_ed = expected_value entry_delay_principle entry_delay_ensemble in
  let n_events = int_of_float (floor (structure_duration /. avg_ed)) in
  let _ = Printf.printf "estimated events: %d" n_events in
  let instr_arr = ensemble_values instrument_ensemble in
  let ed_arr = ensemble_values entry_delay_ensemble in
  let instr_seq = sel_seq_of_array n_events instrument_principle instr_arr in
  let ed_seq =
    sel_seq_of_array n_events entry_delay_principle ed_arr
    |> Seq.map entry_to_float
  in
  let pairs = Seq.zip instr_seq ed_seq |> Seq.take n_events |> List.of_seq in
  let _, events =
    List.fold_left
      (fun (time, acc) (instr, ed) ->
        let (Instrument { chordsize = Chordsize { minsize; maxsize }; _ }) =
          instr
        in
        let chordsize =
          if minsize = maxsize then minsize
          else Random.int (maxsize - minsize + 1) + minsize
        in
        (time +. ed, { time; instrument = instr; chordsize } :: acc))
      (0.0, []) pairs
  in
  List.rev events
