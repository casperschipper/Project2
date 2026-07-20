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
type hierarchy_elem = Ins | Per | Dyn | Dur | Ent

(* | Har
  | Int
*)
type hierarchy = hierarchy_elem list

let all_hierarchy_elems = [ Ins; Per; Dyn; Dur; Ent ]

let hierarchy_elem_to_string = function
  | Ins -> "Ins"
  | Per -> "Per"
  | Dyn -> "Dyn"
  | Dur -> "Dur"
  | Ent -> "Ent"

type density_reason = DensityTooSmall | DensityMaxBelowMin
type duration_range_reason = DurationRangeNegative | DurationRangeMaxBelowMin

type problem =
  | NegativeEntry of float
  | InvalidInstrumentName
  | InvalidChordSize
  | TableSizeMismatch of { instrument_rows : int; other_rows : int }
  | InvalidDensity of density_reason
  | UnknownPerformance of string
  | UnknownDynamic of string
  | InvalidPitchCompass
  | DuplicateHierarchy
  | IncompleteHierarchy of hierarchy_elem list
  | InstrumentDensityRequiresInsFirst
  | NegativeDuration of float
  | InvalidDurationRange of duration_range_reason
  | ParseError of string
  | RatioAllBlocked of { row : int list }
  | PerNoteRequiresInsFirst

(* The hierarchy must be a permutation of [all_hierarchy_elems]: every
   parameter controls exactly one resolution step, so a missing one would
   leave that parameter unresolved (see e.g. [notes_of_proto]'s [assert
   false] in score_generation.ml), and a repeated one is meaningless. *)
let mk_hierarchy (lst : hierarchy_elem list) =
  let deduped = List.sort_uniq compare lst in
  if List.length deduped <> List.length lst then Error DuplicateHierarchy
  else
    let missing =
      all_hierarchy_elems |> List.filter (fun e -> not (List.mem e lst))
    in
    match missing with [] -> Ok lst | _ -> Error (IncompleteHierarchy missing)

let display_problem p =
  match p with
  | NegativeEntry x ->
      "entry delay is" ^ string_of_float x ^ ", but may not be negative"
  | InvalidInstrumentName -> "instrument name may not be empty"
  | InvalidChordSize -> "illegal chord size limit, cannot be zero"
  | TableSizeMismatch { instrument_rows; other_rows } ->
      Printf.sprintf
        "instrument table has %d row(s) but this table has %d; sizes must \
         match for 'combination' to align rows 1:1"
        instrument_rows other_rows
  | InvalidDensity DensityTooSmall -> "invalid density definition: low must be at least 1"
  | InvalidDensity DensityMaxBelowMin ->
      "invalid density definition: max should not be higher than min"
  | UnknownPerformance s -> "unknown performance mode: " ^ s
  | UnknownDynamic s -> "unknown dynamic mode: " ^ s
  | InvalidPitchCompass -> "pitch compass minimum must not exceed maximum"
  | DuplicateHierarchy -> "each hierarchy level may only appear once"
  | IncompleteHierarchy missing ->
      Printf.sprintf "hierarchy is missing: %s"
        (missing |> List.map hierarchy_elem_to_string |> String.concat ", ")
  | InstrumentDensityRequiresInsFirst ->
      "InstrumentDensity requires Ins to be first in the hierarchy"
  | NegativeDuration x ->
      "duration is " ^ string_of_float x ^ ", but may not be negative"
  | InvalidDurationRange DurationRangeNegative -> "duration may not be negative"
  | InvalidDurationRange DurationRangeMaxBelowMin -> "min duration exceeds max duration"
  | ParseError msg -> "parse error: " ^ msg
  | RatioAllBlocked { row } ->
      Printf.sprintf
        "this table row (%s) has every element blocked (ratio weight 0); \
         selecting it could never produce a value"
        (row |> List.map string_of_int |> String.concat " ")
  | PerNoteRequiresInsFirst ->
      "this parameter is per-note: Ins must precede it in the hierarchy \
       (chord size isn't known until an instrument is picked)"

(* Closed vocabulary of path components identifying where in a
   structure_formula (and, one level down, in the composer's sexp) a
   [problem] belongs - reused contextually across path positions rather than
   having one variant per (kind, position) pair. E.g. [KPerformance] appears
   both as a parameter kind ([KPerformance; KCombination]) and, nested, as
   one instrument's own performance field ([KInstrument; Index i;
   KPerformance]) - the surrounding path disambiguates, not the atom itself.
   [K]-prefixed (mirroring this file's existing [Instrument]/[Table]/
   [Duration]/[Entrydelay]/etc. constructors, which plain names would
   collide with). *)
type key =
  | KGlobal
  | KSeed
  | KVariantDuration
  | KInstrument
  | KInstrumentCount
  | KName
  | KChordsize
  | KCompass
  | KDurations
  | KList
  | KTable
  | KPrinciple
  | KCombination
  | KMode
  | KRelation
  | KRow
  | KEntrydelay
  | KDuration
  | KPerformance
  | KDynamics
  | KDensity
  | KHierarchy
  | KUnion

type segment = Key of key | Index of int
type location = segment list

(* [severity]/[Error]/[Warning] can't be a bare top-level type here - it
   would shadow [Result]'s [Error]/[Ok] for the rest of this file (and for
   every file that [open]s [Parameters]). Isolated in its own module instead,
   the same way this codebase already isolates e.g. [Sexp.List]/[Sexp.Atom]
   from [List]. Always used qualified ([Severity.Error]/[Severity.Warning]),
   never [open]ed. *)
module Severity = struct
  type t = Error | Warning
end

(* Warnings are non-fatal: a structure_formula with only warnings still
   builds and the score still generates (mirrors score_generation.ml's
   "IMPOSSIBLE" annotations, which are advisory and never block generation).
   Errors remain fully blocking. *)
type diagnostic = { location : location; severity : Severity.t; problem : problem }

let key_to_string = function
  | KGlobal -> "global"
  | KSeed -> "seed"
  | KVariantDuration -> "variant-duration"
  | KInstrument -> "instrument"
  | KInstrumentCount -> "number-of-instrument-groups"
  | KName -> "name"
  | KChordsize -> "chordsize"
  | KCompass -> "compass"
  | KDurations -> "durations"
  | KList -> "list"
  | KTable -> "table"
  | KPrinciple -> "principle"
  | KCombination -> "combination"
  | KMode -> "mode"
  | KRelation -> "relation"
  | KRow -> "row"
  | KEntrydelay -> "entrydelay"
  | KDuration -> "duration"
  | KPerformance -> "performance"
  | KDynamics -> "dynamics"
  | KDensity -> "density"
  | KHierarchy -> "hierarchy"
  | KUnion -> "union"

let segment_to_string = function
  | Key k -> key_to_string k
  | Index i -> Printf.sprintf "[%d]" i

(* e.g. [Key KInstrument; Index 2; Key KChordsize] -> "instrument[2].chordsize"
   [Key KDuration; Key KTable; Key KRow; Index 3] -> "duration.table.row[3]"
   [Key KDynamics; Key KCombination] -> "dynamics.combination" *)
let location_to_string = function
  | [] -> "(root)"
  | seg0 :: rest ->
      List.fold_left
        (fun acc seg ->
          match seg with
          | Index _ -> acc ^ segment_to_string seg
          | Key _ -> acc ^ "." ^ segment_to_string seg)
        (segment_to_string seg0) rest

let severity_to_string = function
  | Severity.Error -> "ERROR"
  | Severity.Warning -> "WARNING"

let display_diagnostic { location; severity; problem } =
  Printf.sprintf "[%s] %s: %s" (location_to_string location)
    (severity_to_string severity) (display_problem problem)

let print_diagnostics label diags =
  Printf.printf "%s:\n" label;
  List.iter (fun d -> Printf.printf "  - %s\n" (display_diagnostic d)) diags;
  flush stdout

let entry_to_float (Entrydelay x) = x
(* let value_to_float v = match v with Entry (Entrydelay x) -> x *)

let mk_instr str =
  match str with
  | "" -> Error InvalidInstrumentName
  | nonEmpty -> Ok (InstrumentName nonEmpty)

let mk_entrydelay ed =
  if ed < 0.0 then Error (NegativeEntry ed) else Ok (Entrydelay ed)

let mk_duration d =
  if d < 0.0 then Error (NegativeDuration d) else Ok (Duration d)

(* This is the full list of parameters, currently a should only be instr or entrydelay *)
type 'a parameter_list = ParameterList of 'a Array.t

(* we keep indexes that produced a value from the list, they may be useful *)
type 'a element = { index : int; value : 'a }

let value_from_element { value; index } =
  ignore index;
  value

(* wraps a plain array as elements whose index is simply their position -
   for arrays that never went through a LIST -> TABLE -> ENSEMBLE stage (e.g.
   the synthetic density range), so they can still be fed to functions that
   expect indexed elements (e.g. RATIO's per-index weighting) *)
let elements_of_array arr = Array.mapi (fun index value -> { index; value }) arr

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

type register = Register of int

let reg2int (Register i) = i

type absolute_pitch = Absolute of register * int
type relative_pitch = Relative of int

let absolute_koenig absolute = (absolute / 100, absolute mod 100)
let absolute register relative = Absolute (register, relative)

let absolute_of_koenig n =
  let oct, rel = absolute_koenig n in
  Absolute (Register oct, rel)

let absolute_compare (Absolute (Register o1, r1)) (Absolute (Register o2, r2)) =
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

type allowed_durations = AllowedDurations of { min : float; max : float }

let print_allowed_durations (AllowedDurations { min; max }) =
  Printf.sprintf "Allowed durations: from %f till %f" min max

let mk_allowed_durations mini maxi =
  if mini < 0.0 || maxi < 0.0 then Error (InvalidDurationRange DurationRangeNegative)
  else if mini > maxi then Error (InvalidDurationRange DurationRangeMaxBelowMin)
  else Ok (AllowedDurations { min = mini; max = maxi })

(* an instrument, may also have certain limitations *)
type instrument =
  | Instrument of {
      instrument : instr;
      chordsize : chordsize;
      durations : allowed_durations;
      performance : Performance_modes.t;
      dynamics : Dynamic_modes.t;
      pitchcompass : pitch_compass;
    }

(* both performance and dynamics have an explicit master list (parsed from
   the structure formula's top-level "performance" / "dynamics" fields);
   every instrument's own (performance (...)) / (dynamics (...)) must be a
   subset of the corresponding master list *)
let check_instrument_performances_known known_performances instrs : diagnostic list =
  instrs
  |> List.mapi (fun i (Instrument { performance; _ }) ->
      Performance_modes.diff performance known_performances
      |> Performance_modes.to_list
      |> List.map (fun p ->
          {
            location = [ Key KInstrument; Index i; Key KPerformance ];
            severity = Severity.Error;
            problem = UnknownPerformance (Performance.to_string p);
          }))
  |> List.concat

let check_instrument_dynamics_known known_dynamics instrs : diagnostic list =
  instrs
  |> List.mapi (fun i (Instrument { dynamics; _ }) ->
      Dynamic_modes.diff dynamics known_dynamics
      |> Dynamic_modes.to_list
      |> List.map (fun d ->
          {
            location = [ Key KInstrument; Index i; Key KDynamics ];
            severity = Severity.Error;
            problem = UnknownDynamic (Dynamic.to_string d);
          }))
  |> List.concat

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
               min = Absolute (Register min_oct, min_rel);
               max = Absolute (Register max_oct, max_rel);
               forbidden;
             };
         durations;
       }) =
  let perfs =
    Performance_modes.elements performance
    |> List.map Performance.to_string
    |> String.concat ","
  in
  let dyns =
    Dynamic_modes.elements dynamics
    |> List.map Dynamic.to_string |> String.concat ","
  in
  let forbidden_str =
    Pitch_set.elements forbidden |> List.map string_of_int |> String.concat ","
  in
  Printf.printf
    "instrument: %s, chordsize: %d-%d, performance: [%s], dynamics: [%s], \
     compass: %d%02d-%d%02d, forbidden: [%s], %s\n"
    name minsize maxsize perfs dyns min_oct min_rel max_oct max_rel
    forbidden_str
    (print_allowed_durations durations)

let inst instrument cs performance dynamics pitchcompass durations =
  Instrument
    {
      instrument;
      chordsize = cs;
      performance;
      dynamics;
      pitchcompass;
      durations;
    }

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

let mk_autonomous ~low ~high ~selection_principle =
  if low < 1 then Error (InvalidDensity DensityTooSmall)
  else if high < low then Error (InvalidDensity DensityMaxBelowMin)
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
    Printf.printf
      "construct_ensemble [%s]: principle=combination, number_of_groups=%d\n"
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

(* RATIO weights are declared per LIST index (EMR-3 4.3): [weighted] is the
   composer's (index, weight) list from the sexp. This turns it into a
   lookup, defaulting to weight 0 (blocked) for any list index the composer
   didn't mention. *)
let ratio_weight_of weighted =
  let tbl = Hashtbl.create (List.length weighted) in
  List.iter (fun (i, w) -> Hashtbl.replace tbl i w) weighted;
  fun i -> Option.value (Hashtbl.find_opt tbl i) ~default:0

(* [check_ratio_coverage] flags any table row all of whose LIST indices are
   blocked (weight 0) under a Ratio principle - such a row would produce an
   empty RATIO sampling pool (a crash) if the ensemble ever selected it. *)
let check_ratio_coverage (table_loc : location) (Table rows) principle :
    diagnostic list =
  match principle with
  | Ratio weighted ->
      let weight_of = ratio_weight_of weighted in
      rows |> Array.to_list
      |> List.mapi (fun row_i row -> (row_i, row))
      |> List.filter_map (fun (row_i, row) ->
          if
            Array.length row > 0 && Array.for_all (fun i -> weight_of i = 0) row
          then
            Some
              {
                location = table_loc @ [ Key KRow; Index row_i ];
                severity = Severity.Warning;
                problem = RatioAllBlocked { row = Array.to_list row };
              }
          else None)
  | _ -> []

let expected_value selection_principle (array : entrydelay element array) =
  let ensemble =
    array |> Array.map (fun e -> entry_to_float (value_from_element e))
  in
  (* calculates the expected (average) value produced by the selection principle over the ensemble *)
  let array_average arr =
    let sum = Array.fold_left ( +. ) 0.0 arr in
    sum /. Float.of_int (Array.length arr)
  in
  match selection_principle with
  | Alea -> array_average ensemble
  | Series -> array_average ensemble
  | Ratio weighted ->
      (* each ensemble occurrence of LIST index [i] contributes its own
         weight_of i copies to the pool - so an index repeated across the
         ensemble (e.g. via table groups) counts that many times over *)
      let weight_of = ratio_weight_of weighted in
      let pairs =
        array |> Array.to_list
        |> List.map (fun { index; value } ->
            (entry_to_float value, weight_of index))
      in
      let weighted_sum =
        List.fold_left
          (fun acc (v, w) -> acc +. (v *. float_of_int w))
          0.0 pairs
      in
      let total_weight = List.fold_left (fun acc (_, w) -> acc + w) 0 pairs in
      if total_weight = 0 then array_average ensemble
      else weighted_sum /. float_of_int total_weight
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
  List.iter (fun e -> Printf.printf "  - %s\n" (display_problem e)) errors;
  flush stdout

(* HARMONY *)

(* HARMONY has three principles in PR-2: CHORD, ROW and INTERVAL
   (EMR-3 §8.2). This module implements only ROW, the simplest of the
   three: unlike CHORD it never becomes "main parameter" and never
   determines vertical density (that stays independent, see EMR-3 p.115
   / fig 9-5), and unlike INTERVAL it has no constraint matrix to solve -
   it is just a given sequence of steps that gets transposed as a whole
   each time it has been used up. *)

(* Original PR-2 marks a percussion event by "abusing" a pitch value: relative
   pitch 0, and register (0,0). We replace that with a real sum
   type: a tone is either a pitch (a register plus a step within it) or a
   percussion event, which carries no pitch information at all. *)

type step =
  | Step of int (* relative pitch within the tone system, i.e. 1..tr *)

type pitch = Pitched of register * step | Percussion

(* HARMONY (and so ROW) only ever decides the step. The octave placement
   (register) is a separate hierarchy parameter whose order relative to
   HARMONY the composer chooses freely (EMR-3 p.74-77, fig 7-6), so no
   register is known yet at this stage. ROW therefore produces this
   lighter value; combine it with a register, once one is chosen
   elsewhere, via [attach_register]. *)

type row_value = Tone of step | RowPercussion

type harmony_problem =
  | InvalidStep of { n : int; tr : int }
  | InvalidCallNumber of int

let display_harmony_problem = function
  | InvalidStep { n; tr } ->
      Printf.sprintf "relative pitch %d is out of range 1..%d" n tr
  | InvalidCallNumber n ->
      Printf.sprintf "%d is not a valid TRANSP-ROW call number (0-4)" n

let mk_step ~tr n =
  if n < 1 || n > tr then Error (InvalidStep { n; tr }) else Ok (Step n)

(* the composer writes relative pitches 0..tr into the row; 0 is PR-2's
   percussion sentinel, which becomes its own case here instead *)
let mk_row_value ~tr n =
  if n = 0 then Ok RowPercussion
  else mk_step ~tr n |> Result.map (fun s -> Tone s)

type row = Row of row_value array

let mk_row ~tr ints =
  ints
  |> List.map (mk_row_value ~tr)
  |> sequence_result
  |> Result.map (fun lst -> Row (Array.of_list lst))

let attach_register register = function
  | RowPercussion -> Percussion
  | Tone step -> Pitched (register, step)

(* TRANSP-ROW, entry 20 *)
type transposition =
  | NoTransposition (* 0 *)
  | TransposeAlea (* 1 *)
  | TransposeSeries (* 2 *)
  | TransposeChromatic (* 3: ascending sequence 1..tr *)
  | TransposeSerial (* 4: the row itself is reused as transposition intervals *)

let transposition_of_call_number = function
  | 0 -> Ok NoTransposition
  | 1 -> Ok TransposeAlea
  | 2 -> Ok TransposeSeries
  | 3 -> Ok TransposeChromatic
  | 4 -> Ok TransposeSerial
  | n -> Error (InvalidCallNumber n)

let row_value_to_int = function RowPercussion -> 0 | Tone (Step n) -> n

(* SERIES, applied to the fixed range 1..tr: exhausts every interval once
   (in shuffled order) before any interval repeats *)
let series_over_range tr =
  let full = Array.init tr (fun i -> i + 1) in
  let shuffled () = shuffle full |> Array.to_list in
  let f remain =
    match remain with
    | [] -> ( match shuffled () with x :: xs -> Some (x, xs) | [] -> None)
    | x :: xs -> Some (x, xs)
  in
  Seq.unfold f (shuffled ())

(* one transposition interval per completed pass through the row *)
let transposition_intervals ~tr transposition (Row elements) : int Seq.t =
  match transposition with
  | NoTransposition -> Seq.repeat 0
  | TransposeAlea -> choose (List.init tr (fun i -> i + 1))
  | TransposeSeries -> series_over_range tr
  | TransposeChromatic ->
      Seq.cycle (List.to_seq (List.init tr (fun i -> i + 1)))
  | TransposeSerial ->
      Seq.cycle (Array.to_seq (Array.map row_value_to_int elements))

let transpose_step ~tr k (Step n) = Step (((n - 1 + k) mod tr) + 1)

let transpose_value ~tr k = function
  | RowPercussion -> RowPercussion
  | Tone s -> Tone (transpose_step ~tr k s)

(** [row_stream ~tr ~transposition row] is the infinite stream of row values
    PR-2 distributes over entry points: the row as given, then - once it has
    been used up in full - transposed again and again (EMR-3 p.76-77), the
    transposition interval for each pass drawn according to [transposition]. *)
let row_stream ~tr ~transposition (Row elements as row) : row_value Seq.t =
  let intervals = transposition_intervals ~tr transposition row in
  let rec expand cumulative intervals () =
    match intervals () with
    | Seq.Nil -> Seq.Nil
    | Seq.Cons (k, rest) ->
        let pass =
          elements |> Array.to_seq |> Seq.map (transpose_value ~tr cumulative)
        in
        Seq.append pass (expand ((cumulative + k) mod tr) rest) ()
  in
  expand 0 intervals

let row_value_to_string = function
  | RowPercussion -> "*"
  | Tone (Step n) -> string_of_int n

let pitch_to_string = function
  | Percussion -> "*"
  | Pitched (Register r, Step s) -> Printf.sprintf "%d.%d" r s
