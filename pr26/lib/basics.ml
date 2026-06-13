open Tools
open Selection

(* as we are indexing the table groups, we use arrays of ints *)
type ptable = Table of int Array.t Array.t

let count_rows (Table arrarr) = Array.length arrarr

type instr =
  | InstrumentName of string (* the name of an instrument, must be unique *)

type entrydelay =
  | Entrydelay of
      float (* how much time passes from this event to the one that follows *)

type duration = Duration of float (* duration fo the tone *)

type problem =
  | NegativeEntry of float
  | InvalidInstrumentName
  | InvalidChordSize
  | TableSizeMismatch of string
  | InvalidDensity of string
  | UnknownPerformance of string
  | InvalidPitchCompass
  | DuplicateHierarchy
  | InstrumentDensityRequiresInsFirst

type hierarchy_elem = Ins | Per

(* | Dur
  | Har
  | Int
*)
type hierarchy = hierarchy_elem list

let mk_hierarchy (lst : hierarchy_elem list) =
  let deduped = List.sort_uniq compare lst in
  if List.length deduped = List.length lst then Ok lst
  else Error DuplicateHierarchy

let display_problem p =
  match p with
  | NegativeEntry x ->
      "entry delay is" ^ string_of_float x ^ ", but may not be negative"
  | InvalidInstrumentName -> "instrument name may not be empty"
  | InvalidChordSize -> "illegal chord size limit, cannot be zero"
  | TableSizeMismatch table_error -> table_error
  | InvalidDensity str -> "invalid density definition: " ^ str
  | UnknownPerformance s -> "unknown performance mode: " ^ s
  | InvalidPitchCompass -> "pitch compass minimum must not exceed maximum"
  | DuplicateHierarchy -> "each hierarchy level may only appear once"
  | InstrumentDensityRequiresInsFirst ->
      "InstrumentDensity requires Ins to be first in the hierarchy"

let entry_to_float (Entrydelay x) = x
(* let value_to_float v = match v with Entry (Entrydelay x) -> x *)

let mk_instr str =
  match str with
  | "" -> Error InvalidInstrumentName
  | nonEmpty -> Ok (InstrumentName nonEmpty)

let mk_entrydelay ed =
  if ed < 0.0 then Error (NegativeEntry ed) else Ok (Entrydelay ed)

(* This is the full list of parameters, currently a should only be instr or entrydelay *)
type 'a parameter_list = ParameterList of 'a Array.t

(* we keep indexes that produced a value from the list, they may be useful *)
type 'a element = { index : int; value : 'a }

let value_from_element { value; index } =
  ignore index;
  value

type 'a group = EnsembleGroup of 'a element Array.t

let mk_par_list constructor lst =
  lst |> List.map constructor |> sequence_result
  |> Result.map (fun lst -> ParameterList (Array.of_list lst))

let lookup_index (ParameterList arr) i = arr.(i)

type 'a indexed_ensemble_group =
  | IndexedEnsembleGroup of { index : int; group : 'a group }

(* returns the groups from an indexed ensemble as an array *)
let elements_from_indexed_ensemble (IndexedEnsembleGroup { group; _ }) =
  match group with EnsembleGroup gr -> gr

(* an ensemble is a list of groups, we keep the group structure, as they may still be used as separate layers 
  if an ensemble is formed with no_union in another parameter, we only select a single group
*)
type 'a ensemble =
  | Ensemble of 'a indexed_ensemble_group list
  | SingleGroup of 'a indexed_ensemble_group

module Performance = struct
  type t = Performance of string

  let to_string (Performance s) = s
  let of_string s = Performance s
  let compare p1 p2 = String.compare (to_string p1) (to_string p2)
end

module Performance_modes = Set.Make (Performance)

let mk_ensemble group_list = Ensemble group_list
let mk_ensemble_single group = SingleGroup group

let of_nested_list lstlst =
  lstlst |> List.map Array.of_list |> Array.of_list |> fun x -> Table x

type chordsize = Chordsize of { minsize : int; maxsize : int }

(* chordsize is min and max *)
let chordsize mini maxi =
  if mini == 0 then Error InvalidChordSize
  else if maxi == 0 then Error InvalidChordSize
  else Ok (Chordsize { minsize = min mini maxi; maxsize = max mini maxi })

(* a table is an array of arrays *)

let allowed_performances lst =
  let init = Performance_modes.empty in
  lst
  |> List.fold_left
       (fun acc mode -> Performance_modes.add (Performance.of_string mode) acc)
       init

type performance_list = PerformanceList of Performance_modes.t

let mk_performance_list strings = PerformanceList (allowed_performances strings)

let select_performances (PerformanceList known) strings =
  match
    List.find_opt
      (fun s -> not (Performance_modes.mem (Performance.of_string s) known))
      strings
  with
  | Some s -> Error (UnknownPerformance s)
  | None ->
      Ok
        (List.fold_left
           (fun acc s -> Performance_modes.add (Performance.of_string s) acc)
           Performance_modes.empty strings)

let remove_performances (PerformanceList known) strings =
  match
    List.find_opt
      (fun s -> not (Performance_modes.mem (Performance.of_string s) known))
      strings
  with
  | Some s -> Error (UnknownPerformance s)
  | None ->
      Ok
        (List.fold_left
           (fun acc s -> Performance_modes.remove (Performance.of_string s) acc)
           known strings)

module Pitch_set = Set.Make (Int)

type absolute_pitch = Absolute of int * int
type relative_pitch = Relative of int

let absolute_koenig absolute = (absolute / 100, absolute mod 100)
let absolute register relative = Absolute (register, relative)

let absolute_of_koenig n =
  let oct, rel = absolute_koenig n in
  Absolute (oct, rel)

let absolute_compare (Absolute (o1, r1)) (Absolute (o2, r2)) =
  let c = Int.compare o1 o2 in
  if c <> 0 then c else Int.compare r1 r2

type pitch_compass =
  | PitchCompass of {
      min : absolute_pitch;
      max : absolute_pitch;
      forbidden : Pitch_set.t;
    }

let mk_pitch_compass min max forbidden =
  if absolute_compare min max > 0 then Error InvalidPitchCompass
  else Ok (PitchCompass { min; max; forbidden })

(* an instrument, may also have certain limitations *)
type instrument =
  | Instrument of {
      instrument : instr;
      chordsize : chordsize;
      performance : Performance_modes.t;
      pitchcompass : pitch_compass;
    }

(* Proto event used during hierarchical score generation. Each field
   starts empty and is filled in as the hierarchy is applied; entrydelay
   is filled up front since it does not depend on hierarchy order, and
   nr_of_tones is filled when the score is built. *)
type proto_event =
  | Proto of {
      instrument : instrument option;
      entrydelay : entrydelay option;
      nr_of_tones : int option;
      performance : Performance.t option;
    }

let empty_proto =
  Proto
    {
      instrument = None;
      entrydelay = None;
      nr_of_tones = None;
      performance = None;
    }

let extract_performances_from_instruments lst =
  List.fold_right
    (fun (Instrument ins) acc -> Performance_modes.union ins.performance acc)
    lst Performance_modes.empty
  |> Performance_modes.to_list |> Array.of_list
  |> fun arr -> ParameterList arr

let print_instrument
    (Instrument
       {
         instrument = InstrumentName name;
         chordsize = Chordsize { minsize; maxsize };
         performance;
         pitchcompass =
           PitchCompass
             {
               min = Absolute (min_oct, min_rel);
               max = Absolute (max_oct, max_rel);
               forbidden;
             };
       }) =
  let perfs =
    Performance_modes.elements performance
    |> List.map Performance.to_string
    |> String.concat ","
  in
  let forbidden_str =
    Pitch_set.elements forbidden |> List.map string_of_int |> String.concat ","
  in
  Printf.printf
    "instrument: %s, chordsize: %d-%d, performance: [%s], compass: \
     %d%02d-%d%02d, forbidden: [%s]\n"
    name minsize maxsize perfs min_oct min_rel max_oct max_rel forbidden_str

let inst instrument cs performance pitchcompass =
  Instrument { instrument; chordsize = cs; performance; pitchcompass }

(* test materials *)

(* for formation of the ensemble Alea, Series or Sequence will pick the groups from the table *)
type ensemble_group_selection =
  | EnsembleGroupAlea
  | EnsembleGroupSeries
  | EnsembleGroupSequence of int list

type autonomous_density = {
  low : int;
  high : int;
  selection_principle : selection_principle;
}

type vertical_density = Autonomous of autonomous_density | InstrumentDensity
(* | ChordDensity *)
(* not yet implemented*)

let mk_autonomous ~tr ~low ~high ~selection_principle =
  if low < 1 then Error (InvalidDensity "too small")
  else if high > tr then
    Error (InvalidDensity "may not be larger than octave division")
  else if high < low then
    Error (InvalidDensity "max should not be higher than min")
  else Ok (Autonomous { low; high; selection_principle })

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

let section_sq_gen n (TendencySection s) : (unit -> float) Seq.t =
  Seq.init n (fun i ->
      let t = if n <= 1 then 0.0 else Float.of_int i /. Float.of_int (n - 1) in
      let lo = lerp (s.start_min :> float) (s.end_min :> float) t in
      let hi = lerp (s.start_max :> float) (s.end_max :> float) t in
      let lo, hi = if lo <= hi then (lo, hi) else (hi, lo) in
      fun () -> lo +. Random.float (hi -. lo))

(* an alternative version of tendency mask that can be "paused", 
more values of a timeslot can be consumed before moving the boundaries 
*)
let tendency_mask_gen count (ensemble : 'a array) (TendencyMask sections) :
    (unit -> 'a) Seq.t =
  let l = Array.length ensemble in
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
  let counts = List.mapi (fun i f -> f + bonus_arr.(i)) floors in
  List.map2 section_sq_gen counts sections
  |> List.to_seq |> Seq.concat
  |> Seq.map (fun sample_float ->
      fun () ->
       sample_float () *. float_of_int l
       |> floor |> int_of_float |> Array.get ensemble)

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

let choose_series lst =
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
      choose_series ensemble
      |> Seq.concat_map (fun elm -> repeat_n elm (random_value min_rep max_rep))
  | GroupSeries, GroupSeries ->
      let elms = choose_series ensemble in
      let reps = choose_series (range min_rep max_rep) in
      Seq.map2 repeat_n elms reps |> Seq.concat
  | GroupAlea, GroupSeries ->
      let elms = choose ensemble in
      let reps = choose_series (range min_rep max_rep) in
      Seq.map2 repeat_n elms reps |> Seq.concat

(* ensemble formation *)

let group_from_indexes selected_group_index plist group =
  IndexedEnsembleGroup
    {
      index = selected_group_index;
      group =
        EnsembleGroup
          (group
          |> List.map (fun i -> { index = i; value = lookup_index plist i })
          |> Array.of_list);
    }

(** [construct_ensemble parlist table principle number_of_groups] Builds an
    [ensemble] by selecting [number_of_groups] groups from [table].

    - [parlist] : the parameter list used to resolve indexes to values
    - [table] : an array of groups, where each group is an array of indexes into
      [parlist]
    - [principle] : how groups are drawn from the table:
    - [number_of_groups]: how many groups to include in the resulting ensemble

    Returns an [ensemble] whose groups contain fully resolved [element] values.
*)

let select_groups number_of_groups parlist grps =
  grps |> Seq.take number_of_groups
  |> Seq.map (fun (index, group_arr) ->
      group_from_indexes index parlist (Array.to_list group_arr))
  |> List.of_seq |> mk_ensemble

let index_table_groups (Table table) =
  table |> Array.mapi (fun i item -> (i, item))

let construct_ensemble ?(verbose = true) parlist table principle
    number_of_groups =
  let result =
    match principle with
    | EnsembleGroupAlea ->
        table |> index_table_groups |> alea_sq
        |> select_groups number_of_groups parlist
    | EnsembleGroupSeries ->
        table |> index_table_groups |> series_select
        |> select_groups number_of_groups parlist
    | EnsembleGroupSequence sq ->
        let itable = index_table_groups table in
        sequence sq
        |> Seq.map (lookup_arr itable)
        |> select_groups number_of_groups parlist
  in
  if verbose then begin
    let principle_str =
      match principle with
      | EnsembleGroupAlea -> "Alea"
      | EnsembleGroupSeries -> "Series"
      | EnsembleGroupSequence sq ->
          Printf.sprintf "Sequence [%s]"
            (sq |> List.map string_of_int |> String.concat ", ")
    in
    Printf.printf "construct_ensemble: principle=%s, number_of_groups=%d\n"
      principle_str number_of_groups;
    let groups =
      match result with Ensemble lst -> lst | SingleGroup g -> [ g ]
    in
    List.iter
      (fun (IndexedEnsembleGroup { index; group }) ->
        let elements = match group with EnsembleGroup arr -> arr in
        let elem_idxs =
          elements
          |> Array.map (fun e -> string_of_int e.index)
          |> Array.to_list |> String.concat ", "
        in
        Printf.printf "  group[%d]: [%s]\n" index elem_idxs)
      groups
  end;
  result

let group_indexes_from_ensemble instrument_ensemble =
  match instrument_ensemble with
  | Ensemble lst ->
      lst |> List.map (fun (IndexedEnsembleGroup { index; _ }) -> index)
  | SingleGroup (IndexedEnsembleGroup { index; _ }) -> [ index ]

let combination_compatibility (Table instrument_table) (Table other_table) =
  Array.length instrument_table == Array.length other_table

let construct_ensemble_combination ?(verbose = true) parlist table
    instrument_ensemble =
  let indexes = group_indexes_from_ensemble instrument_ensemble in
  let n_groups = List.length indexes in
  let itable = index_table_groups table |> Array.to_list in
  let result = sequence itable |> select_groups n_groups parlist in
  if verbose then begin
    let principle_str = "combination" in
    Printf.printf "construct_ensemble: principle=%s, number_of_groups=%d\n"
      principle_str n_groups;
    let groups =
      match result with Ensemble lst -> lst | SingleGroup g -> [ g ]
    in
    List.iter
      (fun (IndexedEnsembleGroup { index; group }) ->
        let elements = match group with EnsembleGroup arr -> arr in
        let elem_idxs =
          elements
          |> Array.map (fun e -> string_of_int e.index)
          |> Array.to_list |> String.concat ", "
        in
        Printf.printf "  group[%d]: [%s]\n" index elem_idxs)
      groups
  end;
  result

let ensemble_to_array_union ensemble =
  match ensemble with
  | Ensemble e ->
      e
      |> List.map elements_from_indexed_ensemble
      |> Array.concat
      |> Array.map (fun { value; _ } -> value)
  | SingleGroup g ->
      g |> elements_from_indexed_ensemble
      |> Array.map (fun { value; index } ->
          ignore index;
          value)

let expected_value selection_principle array =
  let ensemble = array |> Array.map entry_to_float in
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
  | Combination
  (* index of combined parameters is the same as instrument *)
  | NoCombination
(* parameter selects their own group (independent of the groups indexes of instrument) *)

type union =
  | Union
  (* ensemble groups merged into a single unit, no layers *)
  | NoUnion
(* the number of layers is equal to the number of groups in the ensemble, the combined parameters also have same number of groups *)

(* we combine all the parameters currently supported into one record, so we can validate dependencies 
current dependencies include, the number of groups in 
*)
type structure_formula = {
  variant_duration : float;
  instr_list : instrument parameter_list;
  instr_table : ptable;
  ed_list : entrydelay parameter_list;
  ed_table : ptable;
  number_of_instrument_groups : int;
  performance_table : ptable;
  instrument_principle : selection_principle;
  entrydelay_principle : selection_principle;
  entrydelay_combination : combination;
  performance_principle : selection_principle;
  performance_combination : combination;
  union : union;
  density : vertical_density;
  hierarchy : hierarchy;
}

let check_combination label instr_table other_table = function
  | Combination when not (combination_compatibility instr_table other_table) ->
      [
        TableSizeMismatch
          (Printf.sprintf
             "instrument (size %d) and %s table (size %d) are not of \
              compatible size"
             (count_rows instr_table) label (count_rows other_table));
      ]
  | _ -> []

let mk_structure_formula ~variant_duration ~instr_list ~instr_table ~ed_list
    ~ed_table ~number_of_instrument_groups ~performance_table
    ~entrydelay_combination ~instrument_principle ~entrydelay_principle
    ~performance_principle ~performance_combination ~union ~density ~hierarchy =
  let hierarchy_errors =
    match (density, hierarchy) with
    | InstrumentDensity, first :: _ ->
        if first == Ins then [] else [ InstrumentDensityRequiresInsFirst ]
    | _ -> []
  in
  let combination_errors =
    check_combination "entrydelay" instr_table ed_table entrydelay_combination
    @ check_combination "performance" instr_table performance_table
        performance_combination
  in
  match hierarchy_errors @ combination_errors with
  | [] ->
      Ok
        {
          variant_duration;
          instr_list;
          instr_table;
          ed_list;
          ed_table;
          number_of_instrument_groups;
          performance_table;
          entrydelay_combination;
          instrument_principle;
          entrydelay_principle;
          performance_principle;
          performance_combination;
          union;
          density;
          hierarchy;
        }
  | errs -> Error errs

(* ---- Score generation ---- *)

type score_event = {
  time : float;
  instrument : instr;
  chordsize : int;
  performance : Performance.t;
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

(** Build a finite section of values based on principle and array *)
let sel_seq_of_array n principle arr =
  match principle with
  | Alea -> alea_sq arr |> Seq.take n
  | Series -> series_select arr |> Seq.take n
  | Ratio ratios ->
      ratios
      |> List.concat_map (fun (i, n) -> repeat arr.(i) n)
      |> Array.of_list |> series_select |> Seq.take n
  | Group groupspec -> group_sq (Array.to_list arr) groupspec |> Seq.take n
  | Sequence indices ->
      sequence indices |> Seq.map (fun i -> arr.(i)) |> Seq.take n
  | Tendency sections -> tendency_mask n arr sections
(* NOTE: unlike the others, this has a certain number of events *)

(** Like [sel_seq_of_array] but returns [n] per-time-point generators. Calling a
    generator multiple times stays at the same "position" within the overall
    sequence, so Tendency boundaries are frozen for a whole time point and only
    advance when the outer sequence moves to the next element. For all
    non-Tendency principles, a single shared mutable sequence is threaded
    continuously across time points (the series does not restart per time
    point). *)
let sel_seq_gen_of_array n principle (arr : 'a array) : (unit -> 'a) Seq.t =
  let l = Array.length arr in
  match principle with
  | Alea ->
      let gen () = arr.(Random.int l) in
      Seq.init n (fun _ -> gen)
  | Series ->
      let state = ref (series_select arr) in
      let gen () =
        match Seq.uncons !state with
        | None -> arr.(0)
        | Some (v, rest) ->
            state := rest;
            v
      in
      Seq.init n (fun _ -> gen)
  | Ratio ratios ->
      let ratio_arr =
        ratios
        |> List.concat_map (fun (i, cnt) -> repeat arr.(i) cnt)
        |> Array.of_list
      in
      let state = ref (series_select ratio_arr) in
      let gen () =
        match Seq.uncons !state with
        | None -> arr.(0)
        | Some (v, rest) ->
            state := rest;
            v
      in
      Seq.init n (fun _ -> gen)
  | Group groupspec ->
      let state = ref (group_sq (Array.to_list arr) groupspec) in
      let gen () =
        match Seq.uncons !state with
        | None -> arr.(0)
        | Some (v, rest) ->
            state := rest;
            v
      in
      Seq.init n (fun _ -> gen)
  | Sequence indices ->
      let state = ref (sequence indices |> Seq.map (fun i -> arr.(i))) in
      let gen () =
        match Seq.uncons !state with
        | None -> arr.(0)
        | Some (v, rest) ->
            state := rest;
            v
      in
      Seq.init n (fun _ -> gen)
  | Tendency sections -> tendency_mask_gen n arr sections

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

let sel_seq_of_ensemble_no_union n principle ensemble =
  ensemble |> ensemble_values_no_union
  |> List.map (fun arr -> sel_seq_of_array n principle arr)

let calculate_number_of_events variant_duration entry_delay_principle
    entry_delay_ensemble =
  let avg_ed = expected_value entry_delay_principle entry_delay_ensemble in
  int_of_float (floor (variant_duration /. avg_ed))

let calculate_layer n_events instrument_principle inst_arr entry_delay_principle
    ed_arr =
  let instr_seq = sel_seq_of_array n_events instrument_principle inst_arr in
  let ed_seq =
    sel_seq_of_array n_events entry_delay_principle ed_arr
    |> Seq.map entry_to_float
  in
  let pairs = Seq.zip instr_seq ed_seq |> Seq.take n_events |> List.of_seq in
  let _, events =
    List.fold_left
      (fun (time, acc) (instr, ed) ->
        let (Instrument
               { chordsize = Chordsize { minsize; maxsize }; instrument; _ }) =
          instr
        in
        let chordsize =
          if minsize = maxsize then minsize
          else Random.int (maxsize - minsize + 1) + minsize
        in
        let performance = Performance.of_string "dummy" in
        (time +. ed, { time; instrument; chordsize; performance } :: acc))
      (0.0, []) pairs
  in
  List.rev events

let calculate_layer_autonomous_density auto_density n_events
    instrument_principle inst_arr entry_delay_principle ed_arr =
  let density_list =
    List.init
      (auto_density.high - auto_density.low + 1)
      (fun i -> i + auto_density.low)
  in
  let _ = print_int_list "Possible densities as follows" density_list in
  let density_array = Array.of_list density_list in
  let density_seq =
    sel_seq_of_array n_events auto_density.selection_principle density_array
  in
  let ed_seq =
    sel_seq_of_array n_events entry_delay_principle ed_arr
    |> Seq.map entry_to_float
  in
  let pairs = Seq.zip ed_seq density_seq |> Seq.take n_events |> List.of_seq in
  let gen_seq = sel_seq_gen_of_array n_events instrument_principle inst_arr in
  let rec fill_to_density time gen remaining acc =
    if remaining <= 0 then acc
    else
      let instr = gen () in
      let (Instrument
             { chordsize = Chordsize { minsize; maxsize }; instrument; _ }) =
        instr
      in
      let chordsize =
        if minsize = maxsize then minsize
        else Random.int (maxsize - minsize + 1) + minsize
      in
      let actual_chordsize = min chordsize remaining in
      let perf = Performance.of_string "dummy" in
      fill_to_density time gen
        (remaining - actual_chordsize)
        ({ time; instrument; chordsize = actual_chordsize; performance = perf }
        :: acc)
  in
  let _, _, events =
    List.fold_left
      (fun (time, gen_seq, acc) (ed, density) ->
        match Seq.uncons gen_seq with
        | None -> (time +. ed, gen_seq, acc)
        | Some (gen, rest) ->
            let new_events = fill_to_density time gen density [] in
            (time +. ed, rest, new_events @ acc))
      (0.0, gen_seq, []) pairs
  in
  List.rev events

(* ---- Hierarchical layer calculation ---- *)

(* States threaded through the hierarchy fold — one per parameter hierarchy controls.
   [instr_arr] is kept here so the Per step can constrain itself to performances
   achievable by at least one instrument in this group, even before Ins runs. *)
type layer_states = {
  instr_state : instrument sel_state;
  perf_state : Performance.t sel_state;
  instr_arr : instrument array;
}

(* One step of the hierarchy fold.
   [protos] is the list being built up; [states] carries the selector states.
   Returns updated [(protos, states)] with one more field filled per event.

   Conditioning rules:
   - Ins step: if Per already ran (performance is set), restrict to
     instruments whose modes include that performance.
   - Per step: if Ins already ran (instrument is set), restrict to that
     instrument's modes; if Ins has not run yet, restrict to performances
     achievable by at least one instrument in this group, so that when Ins
     runs next it can always find a compatible match. *)
let apply_step (protos, states) (elem : hierarchy_elem) =
  match elem with
  | Ins ->
      let instr_state', filled =
        List.fold_left_map
          (fun st (Proto pe) ->
            let pred =
              match pe.performance with
              | None -> Fun.const true
              | Some perf ->
                  fun (Instrument { performance = modes; _ }) ->
                    Performance_modes.mem perf modes
            in
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
          match (pe.instrument, pe.performance) with
          | ( Some
                (Instrument
                   {
                     instrument;
                     chordsize = Chordsize { minsize; maxsize };
                     _;
                   }),
              Some performance ) ->
              let chordsize =
                if minsize = maxsize then minsize
                else Random.int (maxsize - minsize + 1) + minsize
              in
              Some { time = t; instrument; chordsize; performance }
          | _ -> None
        in
        (t +. ed, match event with Some e -> e :: acc | None -> acc))
      (0.0, []) protos
  in
  List.rev events

(** Calculate one layer using the hierarchy list. Entry delays are always
    computed first (independent of hierarchy order) and stored on each proto
    up front. The hierarchy then specifies the order in which [Ins] and [Per]
    are filled, where later steps can condition on earlier ones. *)
let calculate_layer_hierarchical ~n_events ~hierarchy ~instr_arr
    ~instr_principle ~ed_arr ~ed_principle ~perf_arr ~perf_principle =
  let eds =
    sel_seq_of_array n_events ed_principle ed_arr
    |> Seq.map entry_to_float |> List.of_seq
  in
  let init_states =
    {
      instr_state = sel_init instr_principle n_events instr_arr;
      perf_state = sel_init perf_principle n_events perf_arr;
      instr_arr;
    }
  in
  let protos =
    List.map
      (fun ed ->
        let (Proto p) = empty_proto in
        Proto { p with entrydelay = Some (Entrydelay ed) })
      eds
  in
  let filled, _ = List.fold_left apply_step (protos, init_states) hierarchy in
  protos_to_events filled

(** Generate a list of score events, using instrument based vertical density *)
let generate_score ~variant_duration ~instrument_ensemble ~instrument_principle
    ~entry_delay_ensemble ~entry_delay_principle ~union ~density:_density =
  match union with
  | Union ->
      (* flatten all the indexed groups of the ensemble into one *)
      let entr_arr = entry_delay_ensemble |> ensemble_values_union in
      let instr_arr = ensemble_values_union instrument_ensemble in
      let n_events =
        calculate_number_of_events variant_duration entry_delay_principle
          entr_arr
      in
      let _ = Printf.printf "estimated events: %d \n" n_events in
      [
        (match _density with
        | InstrumentDensity ->
            calculate_layer n_events instrument_principle instr_arr
              entry_delay_principle entr_arr
        | Autonomous autodensity ->
            calculate_layer_autonomous_density autodensity n_events
              instrument_principle instr_arr entry_delay_principle entr_arr);
      ]
  | NoUnion ->
      (* no union, multiple groups possible for instrument *)
      let instr_arrays = ensemble_values_no_union instrument_ensemble in
      let entr_arr =
        let raw = ensemble_values_no_union entry_delay_ensemble in
        match raw with
        | [ single ] -> List.init (List.length instr_arrays) (fun _ -> single)
        | _ -> raw
      in
      let layer_from_group_arrays instr_array entr_array =
        let n_events =
          calculate_number_of_events variant_duration entry_delay_principle
            entr_array
        in
        let _ = Printf.printf "\nestimated events: %d " n_events in
        match _density with
        | InstrumentDensity ->
            calculate_layer n_events instrument_principle instr_array
              entry_delay_principle entr_array
        | Autonomous autodensity ->
            calculate_layer_autonomous_density autodensity n_events
              instrument_principle instr_array entry_delay_principle entr_array
      in
      (* treat the ensemble as a list of arrays and compute a layer for each group *)
      List.map2 layer_from_group_arrays instr_arrays entr_arr

let generate_score_hierarchical ~variant_duration ~instrument_ensemble
    ~instrument_principle ~entry_delay_ensemble ~entry_delay_principle ~perf_arr
    ~perf_principle ~union ~hierarchy =
  match union with
  | Union ->
      let entr_arr = ensemble_values_union entry_delay_ensemble in
      let instr_arr = ensemble_values_union instrument_ensemble in
      let n_events =
        calculate_number_of_events variant_duration entry_delay_principle
          entr_arr
      in
      let _ = Printf.printf "estimated events: %d\n" n_events in
      [
        calculate_layer_hierarchical ~n_events ~hierarchy ~instr_arr
          ~instr_principle:instrument_principle ~ed_arr:entr_arr
          ~ed_principle:entry_delay_principle ~perf_arr ~perf_principle;
      ]
  | NoUnion ->
      let instr_arrays = ensemble_values_no_union instrument_ensemble in
      let entr_arrays =
        let raw = ensemble_values_no_union entry_delay_ensemble in
        match raw with
        | [ single ] -> List.init (List.length instr_arrays) (fun _ -> single)
        | _ -> raw
      in
      List.map2
        (fun instr_arr entr_arr ->
          let n_events =
            calculate_number_of_events variant_duration entry_delay_principle
              entr_arr
          in
          let _ = Printf.printf "\nestimated events: %d " n_events in
          calculate_layer_hierarchical ~n_events ~hierarchy ~instr_arr
            ~instr_principle:instrument_principle ~ed_arr:entr_arr
            ~ed_principle:entry_delay_principle ~perf_arr ~perf_principle)
        instr_arrays entr_arrays

let build_score cfg =
  let instr_ensemble =
    construct_ensemble cfg.instr_list cfg.instr_table EnsembleGroupSeries
      cfg.number_of_instrument_groups
  in
  let ed_ensemble =
    match cfg.entrydelay_combination with
    | Combination ->
        (* the index of the instrument ensemble groups is reused for entry delay *)
        construct_ensemble_combination cfg.ed_list cfg.ed_table instr_ensemble
    | NoCombination ->
        (* there is only one group for the entry delay ensemble, and it is autonomous *)
        construct_ensemble cfg.ed_list cfg.ed_table EnsembleGroupSeries 1
  in
  let (ParameterList instr_list) = cfg.instr_list in
  let perf_arr =
    let (ParameterList arr) =
      extract_performances_from_instruments (Array.to_list instr_list)
    in
    arr
  in
  match cfg.hierarchy with
  | [] ->
      generate_score ~variant_duration:cfg.variant_duration
        ~instrument_ensemble:instr_ensemble
        ~instrument_principle:cfg.instrument_principle
        ~entry_delay_ensemble:ed_ensemble
        ~entry_delay_principle:cfg.entrydelay_principle ~union:cfg.union
        ~density:cfg.density
  | hierarchy ->
      generate_score_hierarchical ~variant_duration:cfg.variant_duration
        ~instrument_ensemble:instr_ensemble
        ~instrument_principle:cfg.instrument_principle
        ~entry_delay_ensemble:ed_ensemble
        ~entry_delay_principle:cfg.entrydelay_principle ~perf_arr
        ~perf_principle:cfg.performance_principle ~union:cfg.union ~hierarchy
