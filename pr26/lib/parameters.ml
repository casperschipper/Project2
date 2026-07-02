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
  | ParseError of string

type hierarchy_elem = Ins | Per | Dyn

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
  | ParseError msg -> "parse error: " ^ msg

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

module Dynamic = struct
  type t = Dynamic of string

  let to_string (Dynamic s) = s
  let of_string s = Dynamic s
  let compare p1 p2 = String.compare (to_string p1) (to_string p2)
end

module Dynamic_modes = Set.Make (Dynamic)
module Performance_modes = Set.Make (Performance)

let default_dynamics =
  [ "ppp"; "pp"; "p"; "mf"; "f"; "ff"; "fff" ]
  |> List.map Dynamic.of_string |> Dynamic_modes.of_list

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
      dynamics : Dynamic_modes.t;
      pitchcompass : pitch_compass;
    }

(* this function allows you to extract all possible performance modes from the instrument list
in this way, performances do not have to be defined separately (it makes no sense to have a performance mode
for which there is no instrument)
*)
let extract_performances_from_instruments lst =
  List.fold_right
    (fun (Instrument ins) acc -> Performance_modes.union ins.performance acc)
    lst Performance_modes.empty
  |> Performance_modes.to_list |> Array.of_list
  |> fun arr -> ParameterList arr

(* same as extract_performances_from_instruments, but for the dynamics each instrument can play *)
let extract_dynamics_from_instruments lst =
  List.fold_right
    (fun (Instrument ins) acc -> Dynamic_modes.union ins.dynamics acc)
    lst Dynamic_modes.empty
  |> Dynamic_modes.to_list |> Array.of_list
  |> fun arr -> ParameterList arr

let print_instrument
    (Instrument
       {
         instrument = InstrumentName name;
         chordsize = Chordsize { minsize; maxsize };
         performance;
         dynamics;
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
  let dyns =
    Dynamic_modes.elements dynamics
    |> List.map Dynamic.to_string
    |> String.concat ","
  in
  let forbidden_str =
    Pitch_set.elements forbidden |> List.map string_of_int |> String.concat ","
  in
  Printf.printf
    "instrument: %s, chordsize: %d-%d, performance: [%s], dynamics: [%s], \
     compass: %d%02d-%d%02d, forbidden: [%s]\n"
    name minsize maxsize perfs dyns min_oct min_rel max_oct max_rel
    forbidden_str

let inst instrument cs performance dynamics pitchcompass =
  Instrument { instrument; chordsize = cs; performance; dynamics; pitchcompass }

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

let ratio_sq lst =
  let start =
    lst |> List.concat_map (fun (x, n) -> repeat x n) |> Array.of_list
  in
  series_select start

let sequence lst = Seq.cycle (List.to_seq lst)

let sequence_select arr lst =
  sequence lst |> Seq.map (fun i -> lookup_arr arr i)

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

let construct_ensemble ~label ?(verbose = true) ?(to_string = fun _ -> "_")
    parlist table principle number_of_groups =
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
    Printf.printf "construct_ensemble [%s]: principle=%s, number_of_groups=%d\n"
      label principle_str number_of_groups;
    let groups =
      match result with Ensemble lst -> lst | SingleGroup g -> [ g ]
    in
    List.iter
      (fun (IndexedEnsembleGroup { index; group }) ->
        let elements = match group with EnsembleGroup arr -> arr in
        let elem_strs =
          elements
          |> Array.map (fun e ->
              Printf.sprintf "%d:%s" e.index (to_string e.value))
          |> Array.to_list |> String.concat ", "
        in
        Printf.printf "  group[%d]: [%s]\n" index elem_strs)
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

let construct_ensemble_combination ~label ?(verbose = true)
    ?(to_string = fun _ -> "_") parlist table instrument_ensemble =
  let indexes = group_indexes_from_ensemble instrument_ensemble in
  let n_groups = List.length indexes in
  let itable = index_table_groups table |> Array.to_list in
  let result = sequence itable |> select_groups n_groups parlist in
  if verbose then begin
    Printf.printf "construct_ensemble [%s]: principle=combination, number_of_groups=%d\n"
      label n_groups;
    let groups =
      match result with Ensemble lst -> lst | SingleGroup g -> [ g ]
    in
    List.iter
      (fun (IndexedEnsembleGroup { index; group }) ->
        let elements = match group with EnsembleGroup arr -> arr in
        let elem_strs =
          elements
          |> Array.map (fun e ->
              Printf.sprintf "%d:%s" e.index (to_string e.value))
          |> Array.to_list |> String.concat ", "
        in
        Printf.printf "  group[%d]: [%s]\n" index elem_strs)
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
      (* we sample the mask in 1000 steps to have some estimation *)
      let n_samples = 1000 in
      let _, values =
        List.init n_samples id
        |> List.fold_left
             (fun (st, acc) _ ->
               let v, st' = tendency_draw st in
               (st', get_value v :: acc))
             (tendency_init ~count:n_samples ensemble sections, [])
      in
      let sum = List.fold_left ( +. ) 0.0 values in
      sum /. Float.of_int (List.length values)
  | Sequence seq ->
      seq |> List.map (fun i -> ensemble.(i)) |> List.fold_left ( +. ) 0.0
      |> fun sum -> sum /. float_of_int (List.length seq)

let print_errors label errors =
  Printf.printf "%s failed:\n" label;
  List.iter (fun e -> Printf.printf "  - %s\n" (display_problem e)) errors
