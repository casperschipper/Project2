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
type hierarchy_elem = Ins | Per | Dyn | Dur | Ent | Reg | Har

(* | Int *)
type hierarchy = hierarchy_elem list

let all_hierarchy_elems = [ Ins; Per; Dyn; Dur; Ent; Reg; Har ]

let hierarchy_elem_to_string = function
  | Ins -> "Ins"
  | Per -> "Per"
  | Dyn -> "Dyn"
  | Dur -> "Dur"
  | Ent -> "Ent"
  | Reg -> "Reg"
  | Har -> "Har"

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
  | InvalidPitchRange
  | InvalidOctave of int
  | InvalidRegister
  | DuplicateHierarchy
  | IncompleteHierarchy of hierarchy_elem list
  | InstrumentDensityRequiresInsFirst
  | NegativeDuration of float
  | InvalidDurationRange of duration_range_reason
  | ParseError of string
  | RatioAllBlocked of { row : int list }
  | PerNoteRequiresInsFirst
  | InvalidTr of int
  | InvalidRelativePitch of { n : int; tr : int }
  | InvalidTranspositionName of string
  | InvalidNVariants of int
  | InvalidIntervalMatrixSize of { rows : int; cols : int; expected : int }
  | IntervalChordHasRepeatedAdjacentTone of int
  | InvalidIntervalNumber of { n : int; tr : int }
  | DuplicateIntervalMatrixEntry of int
  | AllTonesForbidden of int
  | IntervalPrincipleName of string
  | IntervalMatrixRowHasNoSuccessor of int
  | EmptyChordTable
  | ChordTooLong of { len : int; tr : int }
  | HarmonyRequiresHarFirst
  | ChordPrincipleDensityMismatch
  | IntervalRestrictionsTooStrict of int
  | HarmonyRequiresHarLast
  | ChordPrincipleCommonHarmonyMismatch

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
      "entry delay is " ^ string_of_float x ^ ", but may not be negative"
  | InvalidInstrumentName -> "instrument name may not be empty"
  | InvalidChordSize -> "illegal chord size limit, cannot be zero"
  | TableSizeMismatch { instrument_rows; other_rows } ->
      Printf.sprintf
        "instrument table has %d row(s) but this table has %d; sizes must \
         match for 'combination' to align rows 1:1"
        instrument_rows other_rows
  | InvalidDensity DensityTooSmall ->
      "invalid density definition: low must be at least 1"
  | InvalidDensity DensityMaxBelowMin ->
      "invalid density definition: max should not be higher than min"
  | UnknownPerformance s -> "unknown performance mode: " ^ s
  | UnknownDynamic s -> "unknown dynamic mode: " ^ s
  | InvalidPitchRange -> "pitch range minimum must not exceed maximum"
  | InvalidOctave n -> Printf.sprintf "octave %d is out of range 1-9" n
  | InvalidRegister -> "register low bound must not exceed high bound"
  | DuplicateHierarchy -> "each hierarchy level may only appear once"
  | IncompleteHierarchy missing ->
      Printf.sprintf "hierarchy is missing: %s"
        (missing |> List.map hierarchy_elem_to_string |> String.concat ", ")
  | InstrumentDensityRequiresInsFirst ->
      "InstrumentDensity requires Ins to be first in the hierarchy"
  | NegativeDuration x ->
      "duration is " ^ string_of_float x ^ ", but may not be negative"
  | InvalidDurationRange DurationRangeNegative -> "duration may not be negative"
  | InvalidDurationRange DurationRangeMaxBelowMin ->
      "min duration exceeds max duration"
  | ParseError msg -> "parse error: " ^ msg
  | RatioAllBlocked { row } ->
      Printf.sprintf
        "this table row (%s) has every element blocked (ratio weight 0); \
         selecting it could never produce a value"
        (row |> List.map string_of_int |> String.concat " ")
  | PerNoteRequiresInsFirst ->
      "this parameter is per-note: Ins must precede it in the hierarchy (chord \
       size isn't known until an instrument is picked)"
  | InvalidTr n ->
      Printf.sprintf "tones-per-octave (tr) must be at least 1, got %d" n
  | InvalidRelativePitch { n; tr } ->
      Printf.sprintf "relative pitch %d is out of range 1..%d" n tr
  | InvalidTranspositionName s ->
      Printf.sprintf
        "%S is not a valid transposition (expected none, alea, series, \
         chromatic, or serial)"
        s
  | InvalidNVariants n ->
      Printf.sprintf "number of variants must be at least 1, got %d" n
  | InvalidIntervalMatrixSize { rows; cols; expected } ->
      Printf.sprintf
        "the interval matrix must be %d x %d (tones-per-octave minus one), \
         got %d row(s) of %d"
        expected expected rows cols
  | IntervalChordHasRepeatedAdjacentTone n ->
      Printf.sprintf
        "this chord repeats tone %d between two tones that are next to each \
         other (including wrapping from the last tone back to the first), \
         so no interval can be computed between them"
        n
  | InvalidIntervalNumber { n; tr } ->
      Printf.sprintf "interval %d is out of range 1..%d" n (tr - 1)
  | DuplicateIntervalMatrixEntry n ->
      Printf.sprintf "interval %d is given more than once in the adjacency list" n
  | AllTonesForbidden tr ->
      Printf.sprintf
        "every tone from 1 to %d is forbidden, leaving nothing the interval \
         principle could ever produce"
        tr
  | IntervalPrincipleName s ->
      Printf.sprintf "%S is not a valid harmony principle (expected row or interval)" s
  | IntervalMatrixRowHasNoSuccessor i ->
      Printf.sprintf
        "interval %d has no allowed successor - reaching it will always \
         fall back to \"INTERVAL RESTRICTIONS TOO STRICT\""
        i
  | EmptyChordTable -> "the CHORD table must contain at least one chord"
  | ChordTooLong { len; tr } ->
      Printf.sprintf
        "this chord has %d tone(s), but the pitch grid only has %d tones per \
         octave (tr) - a chord can never have more tones than that"
        len tr
  | HarmonyRequiresHarFirst ->
      "the CHORD principle makes HARMONY the main parameter (EMR-3 9.2): Har \
       must be first in the hierarchy"
  | ChordPrincipleDensityMismatch ->
      "the CHORD principle requires density to be chord-density, and vice \
       versa - HARMONY becomes main parameter and decides vertical density \
       itself (EMR-3 9.2), so the two can never disagree"
  | IntervalRestrictionsTooStrict count ->
      Printf.sprintf
        "%d note(s) in the generated score fell back to \"INTERVAL \
         RESTRICTIONS TOO STRICT\" - at some point during generation, the \
         given interval's row in the matrix had no allowed successor left \
         (either structurally, or because every allowed successor was a \
         forbidden tone). Try loosening the matrix or the forbidden-tones \
         list."
        count
  | HarmonyRequiresHarLast ->
      "union = common-harmony (EMR-3 6.2's \"s=1\") forces HARMONY to \
       resolve once, after every other parameter and across all layers \
       merged in true chronological order - Har must be last in the \
       hierarchy"
  | ChordPrincipleCommonHarmonyMismatch ->
      "the CHORD principle makes HARMONY decide vertical density itself \
       and resolve first (EMR-3 9.2); union = common-harmony requires \
       HARMONY to resolve last, across a merged cross-layer timeline \
       (EMR-3 6.2's \"s=1\") - the two are mutually exclusive"

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
  | KPitchRange
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
  | KRegister
  | KHarmony
  | KTr
  | KTransposition
  | KNVariants
  | KMatrix
  | KRows
  | KChord
  | KAdjacency
  | KForbiddenTones
  | KInvertMatrix
  | KOrder

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
type diagnostic = {
  location : location;
  severity : Severity.t;
  problem : problem;
}

let key_to_string = function
  | KGlobal -> "global"
  | KSeed -> "seed"
  | KVariantDuration -> "variant-duration"
  | KInstrument -> "instrument"
  | KInstrumentCount -> "number-of-instrument-groups"
  | KName -> "name"
  | KChordsize -> "chordsize"
  | KPitchRange -> "pitch-range"
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
  | KRegister -> "register"
  | KHarmony -> "harmony"
  | KTr -> "tr"
  | KTransposition -> "transposition"
  | KNVariants -> "n-variants"
  | KMatrix -> "matrix"
  | KRows -> "rows"
  | KChord -> "chord"
  | KAdjacency -> "adjacency"
  | KForbiddenTones -> "forbidden-tones"
  | KInvertMatrix -> "invert-matrix"
  | KOrder -> "order"

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
  Printf.sprintf "[%s] %s: %s"
    (location_to_string location)
    (severity_to_string severity)
    (display_problem problem)

let print_diagnostics label diags =
  Printf.printf "%s:\n" label;
  List.iter (fun d -> Printf.printf "  - %s\n" (display_diagnostic d)) diags;
  flush stdout

(* ------------------------------------------------------------------ *)
(* Machine-readable diagnostics, for the GUI.                          *)
(*                                                                     *)
(* [problem_id] is the contract with the GUI: a stable kebab-case name  *)
(* per [problem] constructor (per *reason* where a constructor carries  *)
(* one, since the two InvalidDensity reasons are unrelated mistakes for *)
(* the composer). The GUI keys its editable explanatory markdown on     *)
(* these - help/errors/<id>.md - so they must stay stable even when     *)
(* [display_problem]'s English is reworded. Adding a constructor        *)
(* without adding an id here is a compile error, which is the point.    *)
(* ------------------------------------------------------------------ *)
let problem_id = function
  | NegativeEntry _ -> "negative-entry"
  | InvalidInstrumentName -> "invalid-instrument-name"
  | InvalidChordSize -> "invalid-chord-size"
  | TableSizeMismatch _ -> "table-size-mismatch"
  | InvalidDensity DensityTooSmall -> "density-too-small"
  | InvalidDensity DensityMaxBelowMin -> "density-max-below-min"
  | UnknownPerformance _ -> "unknown-performance"
  | UnknownDynamic _ -> "unknown-dynamic"
  | InvalidPitchRange -> "invalid-pitch-range"
  | InvalidOctave _ -> "invalid-octave"
  | InvalidRegister -> "invalid-register"
  | DuplicateHierarchy -> "duplicate-hierarchy"
  | IncompleteHierarchy _ -> "incomplete-hierarchy"
  | InstrumentDensityRequiresInsFirst -> "instrument-density-requires-ins-first"
  | NegativeDuration _ -> "negative-duration"
  | InvalidDurationRange DurationRangeNegative -> "duration-range-negative"
  | InvalidDurationRange DurationRangeMaxBelowMin ->
      "duration-range-max-below-min"
  | ParseError _ -> "parse-error"
  | RatioAllBlocked _ -> "ratio-all-blocked"
  | PerNoteRequiresInsFirst -> "per-note-requires-ins-first"
  | InvalidTr _ -> "invalid-tr"
  | InvalidRelativePitch _ -> "invalid-relative-pitch"
  | InvalidTranspositionName _ -> "invalid-transposition-name"
  | InvalidNVariants _ -> "invalid-n-variants"
  | InvalidIntervalMatrixSize _ -> "invalid-interval-matrix-size"
  | IntervalChordHasRepeatedAdjacentTone _ ->
      "interval-chord-has-repeated-adjacent-tone"
  | InvalidIntervalNumber _ -> "invalid-interval-number"
  | DuplicateIntervalMatrixEntry _ -> "duplicate-interval-matrix-entry"
  | AllTonesForbidden _ -> "all-tones-forbidden"
  | IntervalPrincipleName _ -> "invalid-harmony-principle-name"
  | IntervalMatrixRowHasNoSuccessor _ -> "interval-matrix-row-has-no-successor"
  | EmptyChordTable -> "empty-chord-table"
  | ChordTooLong _ -> "chord-too-long"
  | HarmonyRequiresHarFirst -> "harmony-requires-har-first"
  | ChordPrincipleDensityMismatch -> "chord-principle-density-mismatch"
  | IntervalRestrictionsTooStrict _ -> "interval-restrictions-too-strict"
  | HarmonyRequiresHarLast -> "harmony-requires-har-last"
  | ChordPrincipleCommonHarmonyMismatch -> "chord-principle-common-harmony-mismatch"

(* Minimal JSON writing. Only what the diagnostic shape needs - there is no
   json library in this project's dependencies and pulling one in for three
   value kinds isn't worth it. *)
let json_escape s =
  let buf = Buffer.create (String.length s + 8) in
  String.iter
    (fun c ->
      match c with
      | '"' -> Buffer.add_string buf "\\\""
      | '\\' -> Buffer.add_string buf "\\\\"
      | '\n' -> Buffer.add_string buf "\\n"
      | '\r' -> Buffer.add_string buf "\\r"
      | '\t' -> Buffer.add_string buf "\\t"
      | c when Char.code c < 0x20 ->
          Buffer.add_string buf (Printf.sprintf "\\u%04x" (Char.code c))
      | c -> Buffer.add_char buf c)
    s;
  Buffer.contents buf

let json_string s = "\"" ^ json_escape s ^ "\""
let json_array items = "[" ^ String.concat "," items ^ "]"

let json_obj fields =
  "{"
  ^ String.concat "," (List.map (fun (k, v) -> json_string k ^ ":" ^ v) fields)
  ^ "}"

(* The structured payload. The GUI uses these to fill placeholders in the
   markdown (e.g. the offending name, the two mismatched row counts) so an
   explanation can be specific without the GUI re-parsing English. *)
let json_of_problem_data p =
  match p with
  | NegativeEntry x | NegativeDuration x ->
      json_obj [ ("value", Printf.sprintf "%g" x) ]
  | TableSizeMismatch { instrument_rows; other_rows } ->
      json_obj
        [
          ("instrumentRows", string_of_int instrument_rows);
          ("otherRows", string_of_int other_rows);
        ]
  | UnknownPerformance s | UnknownDynamic s ->
      json_obj [ ("name", json_string s) ]
  | IncompleteHierarchy missing ->
      json_obj
        [
          ( "missing",
            json_array
              (List.map
                 (fun e -> json_string (hierarchy_elem_to_string e))
                 missing) );
        ]
  | ParseError msg -> json_obj [ ("message", json_string msg) ]
  | RatioAllBlocked { row } ->
      json_obj [ ("row", json_array (List.map string_of_int row)) ]
  | InvalidOctave n -> json_obj [ ("octave", string_of_int n) ]
  | InvalidTr n -> json_obj [ ("tr", string_of_int n) ]
  | InvalidRelativePitch { n; tr } ->
      json_obj [ ("n", string_of_int n); ("tr", string_of_int tr) ]
  | InvalidTranspositionName s -> json_obj [ ("name", json_string s) ]
  | InvalidNVariants n -> json_obj [ ("n", string_of_int n) ]
  | InvalidIntervalMatrixSize { rows; cols; expected } ->
      json_obj
        [
          ("rows", string_of_int rows);
          ("cols", string_of_int cols);
          ("expected", string_of_int expected);
        ]
  | IntervalChordHasRepeatedAdjacentTone n ->
      json_obj [ ("n", string_of_int n) ]
  | InvalidIntervalNumber { n; tr } ->
      json_obj [ ("n", string_of_int n); ("tr", string_of_int tr) ]
  | DuplicateIntervalMatrixEntry n -> json_obj [ ("n", string_of_int n) ]
  | AllTonesForbidden tr -> json_obj [ ("tr", string_of_int tr) ]
  | IntervalPrincipleName s -> json_obj [ ("name", json_string s) ]
  | IntervalMatrixRowHasNoSuccessor i -> json_obj [ ("interval", string_of_int i) ]
  | ChordTooLong { len; tr } ->
      json_obj [ ("len", string_of_int len); ("tr", string_of_int tr) ]
  | IntervalRestrictionsTooStrict count -> json_obj [ ("count", string_of_int count) ]
  | InvalidInstrumentName | InvalidChordSize | InvalidDensity _
  | InvalidPitchRange | InvalidRegister | DuplicateHierarchy
  | InstrumentDensityRequiresInsFirst | InvalidDurationRange _
  | PerNoteRequiresInsFirst | EmptyChordTable | HarmonyRequiresHarFirst
  | ChordPrincipleDensityMismatch | HarmonyRequiresHarLast
  | ChordPrincipleCommonHarmonyMismatch ->
      json_obj []

(* [location] is emitted both as the structured segment list (which the GUI
   walks to find the input field to attach the marker to) and as the flat
   dotted string (for display and for coarse matching). *)
let json_of_segment = function
  | Key k -> json_obj [ ("key", json_string (key_to_string k)) ]
  | Index i -> json_obj [ ("index", string_of_int i) ]

let json_of_diagnostic { location; severity; problem } =
  json_obj
    [
      ("id", json_string (problem_id problem));
      ( "severity",
        json_string
          (match severity with
          | Severity.Error -> "error"
          | Severity.Warning -> "warning") );
      ("path", json_string (location_to_string location));
      ("location", json_array (List.map json_of_segment location));
      ("message", json_string (display_problem problem));
      ("data", json_of_problem_data problem);
    ]

let json_of_diagnostics ~ok ~errors ~warnings ~extra =
  json_obj
    ([
       ("ok", if ok then "true" else "false");
       ("errors", json_array (List.map json_of_diagnostic errors));
       ("warnings", json_array (List.map json_of_diagnostic warnings));
     ]
    @ extra)

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

(* EMR-3 relative pitch (§7.1): the step within an octave, 1..tr (tr = tones
   per octave, composer-set via octave-division, 1-99). *)
type step = Step of int

let mk_step ~tr n =
  if n < 1 || n > tr then Error (InvalidRelativePitch { n; tr })
  else Ok (Step n)

let step_to_int (Step n) = n

(* EMR-3 absolute pitch's octave digit (1-9). Named for what it actually is -
   not "register", which in EMR-3 (§7.1) denotes a range of absolute pitches
   (see [register] below), a different concept entirely. *)
type octave = Octave of int

let mk_octave n =
  if n < 1 || n > 9 then Error (InvalidOctave n) else Ok (Octave n)

let octave_to_int (Octave n) = n

(* EMR-3 absolute pitch (§7.1): an octave (1-9) plus a relative pitch within
   it, e.g. 401 = octave 4, step 1. *)
type absolute_pitch = { octave : octave; step : step }

let absolute octave step = { octave; step }

let absolute_pitch_compare a b =
  let c = Int.compare (octave_to_int a.octave) (octave_to_int b.octave) in
  if c <> 0 then c else Int.compare (step_to_int a.step) (step_to_int b.step)

(* [PercussionPitchRange] mirrors [PercussionRegister] below: a percussion
   instrument has no pitch range at all, rather than a degenerate (0,0) one
   - the same "make the sentinel a real variant" move applied to the
   instrument side of the pitch/register relationship. *)
type pitch_range =
  | PitchRange of {
      min : absolute_pitch;
      max : absolute_pitch;
      forbidden : Pitch_set.t;
    }
  | PercussionPitchRange

let mk_pitch_range min max forbidden =
  if absolute_pitch_compare min max > 0 then Error InvalidPitchRange
  else Ok (PitchRange { min; max; forbidden })

(* EMR-3 REGISTER (§7.1, fig 7-3): a range between two absolute pitches,
   which may span octaves - e.g. (401,512) spans octave 4 and octave 5, per
   the manual's own example. Percussion's "0,0" sentinel becomes a real
   variant, mirroring how [pitch] below already replaces Koenig's pitch-0
   hack for HARMONY. *)
type register =
  | PitchRegister of { low : absolute_pitch; high : absolute_pitch }
  | PercussionRegister

let mk_register low high =
  if absolute_pitch_compare low high > 0 then Error InvalidRegister
  else Ok (PitchRegister { low; high })

(* EMR-3 fig 7-6: REGISTER and INSTRUMENT condition each other regardless of
   which comes first in the hierarchy - a percussion instrument can only
   ever be paired with [PercussionRegister], a pitched instrument only with
   a [PitchRegister] whose span overlaps its own pitch range (the instrument
   doesn't have to cover the whole register, just some of it - the actual
   pitch chosen still has to fit both, checked later by [resolve_pitch] and
   the instrument's own [forbidden] set). *)
let register_compatible_with_pitch_range pitchrange reg =
  match (pitchrange, reg) with
  | PercussionPitchRange, PercussionRegister -> true
  | PitchRange { min; max; _ }, PitchRegister { low; high } ->
      absolute_pitch_compare low max <= 0
      && absolute_pitch_compare high min >= 0
  | PercussionPitchRange, PitchRegister _ | PitchRange _, PercussionRegister ->
      false

type allowed_durations = AllowedDurations of { min : float; max : float }

let print_allowed_durations (AllowedDurations { min; max }) =
  Printf.sprintf "Allowed durations: from %f till %f" min max

let mk_allowed_durations mini maxi =
  if mini < 0.0 || maxi < 0.0 then
    Error (InvalidDurationRange DurationRangeNegative)
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
      pitchrange : pitch_range;
    }

(* both performance and dynamics have an explicit master list (parsed from
   the structure formula's top-level "performance" / "dynamics" fields);
   every instrument's own (performance (...)) / (dynamics (...)) must be a
   subset of the corresponding master list *)
let check_instrument_performances_known known_performances instrs :
    diagnostic list =
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
         pitchrange;
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
  let pitch_range_str =
    match pitchrange with
    | PercussionPitchRange -> "percussion"
    | PitchRange
        {
          min = { octave = Octave min_oct; step = Step min_rel };
          max = { octave = Octave max_oct; step = Step max_rel };
          forbidden;
        } ->
        let forbidden_str =
          Pitch_set.elements forbidden
          |> List.map string_of_int |> String.concat ","
        in
        Printf.sprintf "%d%02d-%d%02d, forbidden: [%s]" min_oct min_rel max_oct
          max_rel forbidden_str
  in
  Printf.printf
    "instrument: %s, chordsize: %d-%d, performance: [%s], dynamics: [%s], \
     pitch range: %s, %s\n"
    name minsize maxsize perfs dyns pitch_range_str
    (print_allowed_durations durations)

let inst instrument cs performance dynamics pitchrange durations =
  Instrument
    { instrument; chordsize = cs; performance; dynamics; pitchrange; durations }

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

(* [ChordDensity]: when HARMONY's CHORD principle is selected, vertical
   density is simply whatever size the drawn chord turns out to be (EMR-3
   §9.2) - it can be neither autonomous nor instrument-driven. See
   [harmony_principle]'s [HarmChord] below and
   [mk_structure_formula]'s bidirectional consistency check tying the two
   together. *)
type vertical_density =
  | Autonomous of autonomous_density
  | InstrumentDensity
  | ChordDensity

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
   type: a tone is either a pitch (an absolute pitch, i.e. octave + step) or
   a percussion event, which carries no pitch information at all. [step] and
   [absolute_pitch] live earlier in this file now. *)

type pitch = Pitched of absolute_pitch | Percussion

(* HARMONY (and so ROW) only ever decides the step. The octave placement is a
   separate hierarchy parameter (REGISTER) whose order relative to HARMONY
   the composer chooses freely (EMR-3 p.74-77, fig 7-6), so no register is
   known yet at this stage. ROW therefore produces this lighter value;
   combine it with a register, once one is chosen elsewhere, via
   [resolve_pitch]. *)

type row_value = Tone of step | RowPercussion

(* The composer writes relative pitches 1..tr into the row, or an explicit
   percussion marker (sexp atom "p") - [None] here, never PR-2's 0 sentinel,
   which is now just an ordinary out-of-range relative pitch like any other
   invalid step. *)
let mk_row_value ~tr = function
  | None -> Ok RowPercussion
  | Some n -> mk_step ~tr n |> Result.map (fun s -> Tone s)

type row = Row of row_value array

let mk_row ~tr items =
  items
  |> List.map (mk_row_value ~tr)
  |> sequence_result
  |> Result.map (fun lst -> Row (Array.of_list lst))

(* HARMONY's CHORD principle (EMR-3 §8.2, entries 15-18): the third "row
   principle" - unlike ROW/INTERVAL, a whole chord (tones *and* how many of
   them) is produced per entry point, rather than one tone at a time. Reuses
   [row_value] verbatim: "1..tr or percussion" is exactly TAB-CHORD's own
   "0..tr, 0=percussion" vocabulary. *)
type chord = Chord of row_value array
type chord_table = ChordTable of chord array

let mk_chord ~tr items =
  items
  |> List.map (mk_row_value ~tr)
  |> sequence_result
  |> Result.map (fun lst -> Chord (Array.of_list lst))

let mk_chord_table ~tr (chords : int option list list) =
  match chords with
  | [] -> Error EmptyChordTable
  | _ ->
      chords |> List.map (mk_chord ~tr) |> sequence_result
      |> Result.map (fun lst -> ChordTable (Array.of_list lst))

let count_chord_tones (Chord arr) = Array.length arr

(* EMR-3 §8.2: "Maximum number of tones per group = pitch grid tr." Checked
   as a separate pass (not baked into [mk_chord_table]) so each over-long
   chord can carry its own [Index] in the diagnostic location - mirrors
   [interval_matrix_dead_end_rows]'s own after-the-fact-pass shape. *)
let chord_table_too_long_indices ~tr (ChordTable chords) =
  chords |> Array.to_list
  |> List.mapi (fun i c -> (i, count_chord_tones c))
  |> List.filter (fun (_, len) -> len > tr)

(* EMR-3 §7.1: given a fixed register and a relative pitch already chosen by
   HARMONY, find which octave(s) within the register's span share that
   relative pitch, and take the lowest - e.g. register (401,512), relative
   pitch 5, can occupy 405 or 505; this picks 405. Returns [(pitch, false)]
   when nothing fits (the manual's "wrong pitch... provided with a
   comment"), mirroring [duration_ok]'s Impossible-fallback idiom elsewhere
   in this codebase - the caller decides what to do with a [false] flag. *)
let find_octave_for_step ~low ~high step =
  let lo = octave_to_int low.octave and hi = octave_to_int high.octave in
  List.init (hi - lo + 1) (fun i -> Octave (lo + i))
  |> List.find_opt (fun octave ->
      let candidate = absolute octave step in
      absolute_pitch_compare low candidate <= 0
      && absolute_pitch_compare candidate high <= 0)

(* Combine REGISTER's resolved value with HARMONY's resolved [row_value]
   into a final [pitch]. The two mismatched cases (a percussion register
   paired with a real step, or vice versa) shouldn't arise once [Reg]/[Har]
   condition each other in [score_generation.ml]'s [resolve_step], but are
   handled here too so this function is total. *)
let resolve_pitch reg row_value =
  match (reg, row_value) with
  | PercussionRegister, RowPercussion -> (Percussion, true)
  | PercussionRegister, Tone _ -> (Percussion, false)
  | PitchRegister { low; _ }, RowPercussion -> (Pitched low, false)
  | PitchRegister { low; high }, Tone step -> (
      match find_octave_for_step ~low ~high step with
      | Some octave -> (Pitched (absolute octave step), true)
      | None -> (Pitched low, false))

(* TRANSP-ROW, entry 20: written as an explicit name in the sexp rather than
   the manual's own call number (0-4), matching how every other selection
   principle is already spelled out ("alea", "series", ...) rather than
   numbered. *)
type transposition =
  | NoTransposition
  | TransposeAlea
  | TransposeSeries
  | TransposeChromatic (* ascending sequence 1..tr *)
  | TransposeSerial (* the row itself is reused as transposition intervals *)

let transposition_of_string = function
  | "none" -> Ok NoTransposition
  | "alea" -> Ok TransposeAlea
  | "series" -> Ok TransposeSeries
  | "chromatic" -> Ok TransposeChromatic
  | "serial" -> Ok TransposeSerial
  | s -> Error (InvalidTranspositionName s)

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
  | TransposeChromatic -> Seq.repeat 1
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

(* TRANSP-CHORD, entry 18: like TRANSP-ROW above, but restricted to 4 modes
   instead of 5 - no chromatic mode, and no "serial" (reuse-the-table) mode;
   its own "given row" mode (option 3) is a distinct, separately-authored
   list of transposition intervals instead. *)
type chord_transposition =
  | ChordNoTransposition
  | ChordTransposeAlea
  | ChordTransposeSeries
  | ChordTransposeGiven of step list

let mk_chord_transposition_given ~tr ints =
  ints |> List.map (mk_step ~tr) |> sequence_result
  |> Result.map (fun steps -> ChordTransposeGiven steps)

(* one transposition interval per completed pass through the whole table
   (Array.length table draws) - mirrors [transposition_intervals] exactly,
   generalizing ROW's "per completed pass through the row" to CHORD's table. *)
let chord_transposition_intervals ~tr (ct : chord_transposition) : int Seq.t =
  match ct with
  | ChordNoTransposition -> Seq.repeat 0
  | ChordTransposeAlea -> choose (List.init tr (fun i -> i + 1))
  | ChordTransposeSeries -> series_over_range tr
  | ChordTransposeGiven steps ->
      Seq.cycle (List.to_seq (List.map step_to_int steps))

(* "Chords starting with 0 are excluded from transposition, regardless of
   the numbers which follow" (EMR-3 §8.2) - a whole-chord property, checked
   once per chord. Zeros *within* an otherwise-transposable chord need no
   special handling at all: [transpose_value]'s existing
   [RowPercussion -> RowPercussion] case already leaves them inert. *)
let chord_starts_with_percussion (Chord arr) =
  Array.length arr > 0 && arr.(0) = RowPercussion

let transpose_chord ~tr k (Chord arr as c) =
  if chord_starts_with_percussion c then c
  else Chord (Array.map (transpose_value ~tr k) arr)

(* INTERVAL principle (EMR-3 8.2, entries 21-24): the second "row principle"
   alongside ROW above, producing the same kind of [row_value] stream from a
   different mechanism - a Markov chain walked over intervals rather than a
   fixed, transposed-as-a-whole sequence. [matrix.(i-1).(j-1) = true] means
   interval [j] (1..tr-1) may immediately follow interval [i]. Represented
   densely regardless of how the composer authored it - see
   [mk_interval_matrix]/[matrix_of_chord]/[mk_interval_matrix_from_adjacency]
   below, three different ways to arrive at the same value. *)
type interval_matrix = IntervalMatrix of bool array array

let mk_interval_matrix ~tr (rows : bool array array) =
  let expected = tr - 1 in
  let rows_n = Array.length rows in
  let cols_ok = Array.for_all (fun row -> Array.length row = expected) rows in
  if rows_n <> expected || not cols_ok then
    Error
      (InvalidIntervalMatrixSize
         {
           rows = rows_n;
           cols = (if rows_n = 0 then 0 else Array.length rows.(0));
           expected;
         })
  else Ok (IntervalMatrix rows)

(* EMR-3 8.2 CHORD-INT / example 8-6: derive a matrix from a chord's own
   interval content instead of hand-authoring it. The chord is a cyclic
   sequence of tones, walked in both directions; within each direction,
   every *consecutive pair of intervals* (cyclically) becomes an allowed
   transition. Verified against both the manual's own worked example (chord
   5 6 10, tr=12) and an independently supplied one (chord 1 3 7, tr=12) -
   see test/test_pr26.ml. *)
let matrix_of_chord ~tr (steps : step array) =
  let n = Array.length steps in
  let step_at k =
    let (Step v) = steps.(((k mod n) + n) mod n) in
    v
  in
  let interval a b = ((b - a) mod tr + tr) mod tr in
  let traversal dir =
    Array.init n (fun k ->
        interval (step_at (k * dir)) (step_at ((k + 1) * dir)))
  in
  let repeated_adjacent =
    List.init n (fun i -> (step_at i, step_at (i + 1)))
    |> List.find_opt (fun (a, b) -> a = b)
  in
  match repeated_adjacent with
  | Some (a, _) -> Error (IntervalChordHasRepeatedAdjacentTone a)
  | None ->
      let m = Array.make_matrix (tr - 1) (tr - 1) false in
      let mark seq =
        Array.iteri
          (fun i given -> m.(given - 1).(seq.((i + 1) mod n) - 1) <- true)
          seq
      in
      mark (traversal 1);
      mark (traversal (-1));
      Ok (IntervalMatrix m)

(* A sparse alternative to writing out the full dense matrix by hand: only
   list, for each [given] interval that has any allowed successor at all,
   the [succ] intervals allowed to follow it. Any interval never mentioned
   as a [given] simply stays a fully-forbidden row (matching the shape of
   Fig. 8-5's own example - mostly forbidden, a few allowed successors per
   row - much more practical to write this way than as a dense grid). *)
let mk_interval_matrix_from_adjacency ~tr (entries : (int * int list) list) =
  let max_i = tr - 1 in
  let in_range n = n >= 1 && n <= max_i in
  let all_values =
    entries |> List.concat_map (fun (given, succs) -> given :: succs)
  in
  match List.find_opt (fun n -> not (in_range n)) all_values with
  | Some n -> Error (InvalidIntervalNumber { n; tr })
  | None -> (
      let givens = List.map fst entries in
      match
        List.find_opt
          (fun g -> List.length (List.filter (( = ) g) givens) > 1)
          givens
      with
      | Some g -> Error (DuplicateIntervalMatrixEntry g)
      | None ->
          let m = Array.make_matrix max_i max_i false in
          List.iter
            (fun (given, succs) ->
              List.iter (fun succ -> m.(given - 1).(succ - 1) <- true) succs)
            entries;
          Ok (IntervalMatrix m))

(* BIT, entry 24: flip every cell of whichever matrix resulted above. *)
let invert_matrix (IntervalMatrix m) =
  IntervalMatrix (Array.map (Array.map not) m)

(* Fig. 8-5's own well-formedness caution: a row with no allowed successor at
   all is a genuine dead end (the composer's responsibility to avoid) - but
   only if the chain can ever actually land there in the first place. Two
   ways in: as the very first interval ([interval_next]'s [HaveTone] step
   only offers intervals whose own row has a successor, so a dead-end row
   is never eligible to be chosen first), or via some other row's
   transition into it (column [i] having a checked cell). A row with no
   successor AND no incoming transition can never be reached at all - a
   dead end nobody ever walks into isn't a problem, so it's not flagged.
   (A dead-end row can never itself be a source of a further transition -
   "no successor" means zero outgoing edges - so this is a one-hop check,
   not a full reachability search: nothing transitively reaches a dead end
   except directly, from a row that has a successor of its own.)
   Surfaced as a warning, not an error, at formula-load time (see
   structure_formula.ml); the runtime (score_generation.ml) still degrades
   gracefully ("INTERVAL RESTRICTIONS TOO STRICT") if a reachable one is hit
   anyway. *)
let interval_matrix_dead_end_rows (IntervalMatrix m) =
  let column_has_incoming j = Array.exists (fun row -> row.(j)) m in
  m |> Array.to_list
  |> List.mapi (fun i row -> (i + 1, row))
  |> List.filter (fun (i, row) ->
         (not (Array.exists (fun x -> x) row)) && column_has_incoming (i - 1))
  |> List.map fst

(* XCL-FRQ, entry 23: tones the interval principle may never produce, at
   any point - not even as its very first (ALEA-chosen) tone. *)
let mk_forbidden_tones ~tr (steps : step list) =
  let distinct = List.sort_uniq compare (List.map step_to_int steps) in
  if List.length distinct >= tr then Error (AllTonesForbidden tr) else Ok steps

(* HARM, entry 15: which of the two implemented "row principles" produces
   HARMONY's relative-pitch stream (CHORD, entry 15 call 1, is out of scope -
   see harmony.md). *)
type harmony_principle =
  | HarmRow of { row : row; transposition : transposition }
  | HarmInterval of { matrix : interval_matrix; forbidden_tones : step list }
  | HarmChord of {
      table : chord_table;
      order : selection_principle; (* SEQ-CHORD, entry 17 - the full 6-way
           principle, per the composer's own explicit instruction, not a
           restricted 3-way one. *)
      transposition : chord_transposition;
    }

let percussion_string = "*"

let row_value_to_string = function
  | RowPercussion -> percussion_string
  | Tone (Step n) -> string_of_int n

let pitch_to_string = function
  | Percussion -> percussion_string
  | Pitched { octave = Octave o; step = Step s } -> Printf.sprintf "%d.%d" o s
