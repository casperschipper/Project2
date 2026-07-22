open Parameters
open Selection
open Tools

type combination =
  | Combination
  (* index of combined parameters is the same as instrument parameter 
  It can also be multiple groups within one ensemble, if there are multiple instrument groups*)
  | NoCombination of ensemble_group_selection
(* 
A parameter that is not combined means:
- only one group is selected
- parameter selects their own group in formation of the ensemble
- independent of instrument
*)

type union =
  | Union
  (* ensemble groups merged into a single unit, no layers *)
  | NoUnion

(* MOD-DUR / MOD-DYN / MOD-PERF (EMR-3 7.3/7.5/7.6): one shared mechanism,
   reused by duration, dynamics and performance alike - a parameter is
   either selected once for the whole chord (all notes at one entry point
   share it), or independently per note. *)
type note_mode = PerChord | PerNote

type duration_mode =
  | DurIndependent of note_mode (* mode 0 *)
  | DurEqualsEntry
    (* mode 1, implies PerChord (MOD-DUR must be 0 per the manual) *)
  | DurShorterThanEntry of note_mode
(* If DUR-ENTRY = 2, valid lists must be given and valid ensembles
must be formed for both parameters. If ENTRY DELAY comes first, elements
are rejected in the DURATION ensemble if they are greater than the sel-
ected entry delay. If no "allowed" durations &vailable, a "wrong" dur-
ation is provided with a comment. If, on the other hand, DURATION comes
first, elements in the ENTRY DELAY ensemble which are smaller than the
selected duration are rejected. If such "allowed" entry delays Chord duration all the same*)

(* the number of layers is equal to the number of groups in the ensemble, the combined parameters also have same number of groups *)

type structure_formula = {
  seed : int;
  variant_duration : float;
  instr_list : instrument parameter_list;
  instr_table : ptable;
  number_of_instrument_groups : int;
  instr_ensemble_group_selection : ensemble_group_selection;
  ed_list : entrydelay parameter_list;
  ed_table : ptable;
  dur_list : duration parameter_list;
  dur_table : ptable;
  duration_combination : combination;
  duration_relation_mode : duration_mode;
  duration_principle : selection_principle;
  perf_list : Performance.t parameter_list;
  performance_table : ptable;
  dyn_list : Dynamic.t parameter_list;
  dynamics_table : ptable;
  instrument_principle : selection_principle;
  entrydelay_principle : selection_principle;
  entrydelay_combination : combination;
  performance_principle : selection_principle;
  performance_combination : combination;
  performance_mode : note_mode;
  dynamics_principle : selection_principle;
  dynamics_combination : combination;
  dynamics_mode : note_mode;
  (* REGISTER (EMR-3 7.1): mirrors performance/dynamics exactly - a list of
     [register] values, a table, an ensemble/combination, an order
     principle, and a chord-vs-per-note mode. *)
  reg_list : register parameter_list;
  register_table : ptable;
  register_principle : selection_principle;
  register_combination : combination;
  register_mode : note_mode;
  (* HARMONY (EMR-3 8.2): ROW only (CHORD/INTERVAL are out of scope, see
     harmony.md) - a fixed sequence of relative pitches, transposed as a
     whole once exhausted; no ensemble machinery, since it's its own
     bespoke stream rather than an Alea/Series/Tendency draw. *)
  row : row;
  tr : int;
  transposition : transposition;
  harmony_mode : note_mode;
  union : union;
  density : vertical_density;
  hierarchy : hierarchy;
}

(* When a combination is requested but the two tables' row counts don't
   match, the composer needs to know both which decision to reconsider (the
   combination setting) and which two tables actually disagree - so this
   emits one warning at each of the three locations, all carrying the same
   [TableSizeMismatch] problem. *)
let check_combination ~combination_loc ~instr_table_loc ~other_table_loc
    instr_table other_table combination : diagnostic list =
  match combination with
  | Combination when not (combination_compatibility instr_table other_table) ->
      let mismatch =
        TableSizeMismatch
          {
            instrument_rows = count_rows instr_table;
            other_rows = count_rows other_table;
          }
      in
      [
        {
          location = combination_loc;
          severity = Severity.Warning;
          problem = mismatch;
        };
        {
          location = instr_table_loc;
          severity = Severity.Warning;
          problem = mismatch;
        };
        {
          location = other_table_loc;
          severity = Severity.Warning;
          problem = mismatch;
        };
      ]
  | _ -> []

let mk portion smin smax emin emax =
  let uf = UnitFloat.of_float_exn in
  TendencySection
    {
      portion;
      start_min = uf smin;
      start_max = uf smax;
      end_min = uf emin;
      end_max = uf emax;
    }

let mk_structure_formula ~seed ~variant_duration ~instr_list ~instr_table
    ~instr_ensemble_group_selection ~ed_list ~ed_table
    ~number_of_instrument_groups ~perf_list ~performance_table ~dyn_list
    ~dynamics_table ~entrydelay_combination ~instrument_principle
    ~entrydelay_principle ~performance_principle ~performance_combination
    ~performance_mode ~dynamics_principle ~dynamics_combination ~dynamics_mode
    ~reg_list ~register_table ~register_principle ~register_combination
    ~register_mode ~row ~tr ~transposition ~harmony_mode ~union ~hierarchy
    ~density ~dur_list ~dur_table ~duration_combination
    ~duration_relation_mode ~duration_principle =
  let hierarchy_errors =
    match (density, hierarchy) with
    | InstrumentDensity, first :: _ ->
        if first == Ins then []
        else
          [
            {
              location = [ Key KHierarchy ];
              severity = Severity.Error;
              problem = InstrumentDensityRequiresInsFirst;
            };
          ]
    | _ -> []
  in
  let combination_errors =
    check_combination
      ~combination_loc:[ Key KEntrydelay; Key KCombination ]
      ~instr_table_loc:[ Key KInstrument; Key KTable ]
      ~other_table_loc:[ Key KEntrydelay; Key KTable ]
      instr_table ed_table entrydelay_combination
    @ check_combination
        ~combination_loc:[ Key KPerformance; Key KCombination ]
        ~instr_table_loc:[ Key KInstrument; Key KTable ]
        ~other_table_loc:[ Key KPerformance; Key KTable ]
        instr_table performance_table performance_combination
    @ check_combination
        ~combination_loc:[ Key KDynamics; Key KCombination ]
        ~instr_table_loc:[ Key KInstrument; Key KTable ]
        ~other_table_loc:[ Key KDynamics; Key KTable ]
        instr_table dynamics_table dynamics_combination
    @ check_combination
        ~combination_loc:[ Key KDuration; Key KCombination ]
        ~instr_table_loc:[ Key KInstrument; Key KTable ]
        ~other_table_loc:[ Key KDuration; Key KTable ]
        instr_table dur_table duration_combination
    @ check_combination
        ~combination_loc:[ Key KRegister; Key KCombination ]
        ~instr_table_loc:[ Key KInstrument; Key KTable ]
        ~other_table_loc:[ Key KRegister; Key KTable ]
        instr_table register_table register_combination
  in
  let (ParameterList instr_arr) = instr_list in
  (* Membership errors are about the offending instrument's own
     (performance ...)/(dynamics ...) field referencing a mode outside the
     master list, not about the master list itself. *)
  let performance_membership_errors =
    let (ParameterList perf_arr) = perf_list in
    check_instrument_performances_known
      (Performance_modes.of_list (Array.to_list perf_arr))
      (Array.to_list instr_arr)
  in
  let dynamics_membership_errors =
    let (ParameterList dyn_arr) = dyn_list in
    check_instrument_dynamics_known
      (Dynamic_modes.of_list (Array.to_list dyn_arr))
      (Array.to_list instr_arr)
  in
  let ratio_coverage_errors =
    check_ratio_coverage
      [ Key KInstrument; Key KTable ]
      instr_table instrument_principle
    @ check_ratio_coverage
        [ Key KEntrydelay; Key KTable ]
        ed_table entrydelay_principle
    @ check_ratio_coverage
        [ Key KPerformance; Key KTable ]
        performance_table performance_principle
    @ check_ratio_coverage
        [ Key KDynamics; Key KTable ]
        dynamics_table dynamics_principle
    @ check_ratio_coverage
        [ Key KDuration; Key KTable ]
        dur_table duration_principle
    @ check_ratio_coverage
        [ Key KRegister; Key KTable ]
        register_table register_principle
    @
    match density with
    | Autonomous { low; high; selection_principle = Ratio _ as p } ->
        let dens_table = Table [| Array.init (high - low + 1) (fun i -> i) |] in
        check_ratio_coverage [ Key KDensity ] dens_table p
    | _ -> []
  in
  (* chordsize (number of notes) is only known once an instrument has been
     picked, so a per-note parameter needs Ins to have already run *)
  let hierarchy_index elem =
    hierarchy
    |> List.mapi (fun i e -> (i, e))
    |> List.find_opt (fun (_, e) -> e = elem)
    |> Option.map fst
  in
  let per_note_ordering_errors =
    let needs_ins_first location elem = function
      | PerChord -> []
      | PerNote -> (
          match (hierarchy_index Ins, hierarchy_index elem) with
          | Some ins_i, Some elem_i when elem_i < ins_i ->
              [
                {
                  location;
                  severity = Severity.Error;
                  problem = PerNoteRequiresInsFirst;
                };
              ]
          | _ -> [])
    in
    let dur_note_mode =
      match duration_relation_mode with
      | DurIndependent m | DurShorterThanEntry m -> m
      | DurEqualsEntry -> PerChord
    in
    needs_ins_first [ Key KPerformance; Key KMode ] Per performance_mode
    @ needs_ins_first [ Key KDynamics; Key KMode ] Dyn dynamics_mode
    @ needs_ins_first [ Key KDuration; Key KRelation ] Dur dur_note_mode
    @ needs_ins_first [ Key KRegister; Key KMode ] Reg register_mode
    @ needs_ins_first [ Key KHarmony; Key KMode ] Har harmony_mode
  in
  let all_diags =
    hierarchy_errors @ combination_errors @ performance_membership_errors
    @ dynamics_membership_errors @ ratio_coverage_errors
    @ per_note_ordering_errors
  in
  match
    List.partition
      (fun (d : diagnostic) -> d.severity = Severity.Error)
      all_diags
  with
  | [], warnings ->
      Ok
        ( {
            seed;
            variant_duration;
            instr_list;
            instr_table;
            instr_ensemble_group_selection;
            ed_list;
            ed_table;
            number_of_instrument_groups;
            perf_list;
            performance_table;
            dyn_list;
            dynamics_table;
            entrydelay_combination;
            instrument_principle;
            entrydelay_principle;
            performance_principle;
            performance_combination;
            performance_mode;
            dynamics_principle;
            dynamics_combination;
            dynamics_mode;
            reg_list;
            register_table;
            register_principle;
            register_combination;
            register_mode;
            row;
            tr;
            transposition;
            harmony_mode;
            union;
            density;
            hierarchy;
            dur_list;
            dur_table;
            duration_relation_mode;
            duration_principle;
            duration_combination;
          },
          warnings )
  | errors, warnings -> Error (errors, warnings)

(* structure formula AST parsers *)

module Parse = struct
  let ( let* ) = Result.bind
  let fail msg = Error [ ParseError msg ]
  let lift r = Result.map_error (fun e -> [ e ]) r

  (* Tags every [problem] a sub-parse can fail with as belonging to
     [location] - applied at each individually-labeled sexp field below, so
     nested leaf failures (a malformed table cell, an unknown mode name, ...)
     automatically inherit the field they were found in without each leaf
     parser needing to know its own context. Every parse-time failure is
     unconditionally [Severity.Error]; the [[]] is "no warnings collected
     yet" - honest, since nothing has been validated at parse time. *)
  let in_loc location r =
    Result.map_error
      (fun problems ->
        ( List.map
            (fun problem -> { location; severity = Severity.Error; problem })
            problems,
          [] ))
      r

  let rec sexp_to_string = function
    | Sexp.Atom s -> s
    | Sexp.List items ->
        "(" ^ (items |> List.map sexp_to_string |> String.concat " ") ^ ")"

  (* Accepts plain decimals ("0.5") as well as literal fractions ("1/2",
     "5/3") - both are reduced to a float immediately, so every caller past
     this point just sees a float and needn't know which spelling was used. *)
  let require_float = function
    | Sexp.Atom s -> (
        match float_of_string_opt s with
        | Some f -> Ok f
        | None -> (
            match String.index_opt s '/' with
            | Some i -> (
                let num_s = String.sub s 0 i in
                let den_s = String.sub s (i + 1) (String.length s - i - 1) in
                match
                  (float_of_string_opt num_s, float_of_string_opt den_s)
                with
                | Some num, Some den when den <> 0.0 -> Ok (num /. den)
                | _ -> fail (Printf.sprintf "expected float, got %S" s))
            | None -> fail (Printf.sprintf "expected float, got %S" s)))
    | Sexp.List _ -> fail "expected float, got list"

  let require_int = function
    | Sexp.Atom s -> (
        let n = ref 0 in
        match
          String.iter
            (fun c ->
              if c >= '0' && c <= '9' then
                n := (!n * 10) + (Char.code c - Char.code '0')
              else raise Exit)
            s
        with
        | () -> Ok !n
        | exception Exit -> fail (Printf.sprintf "expected int, got %S" s))
    | Sexp.List _ -> fail "expected int, got list"

  let require_atom = function
    | Sexp.Atom s -> Ok s
    | Sexp.List _ -> fail "expected atom, got list"

  let sequence lst =
    List.fold_right
      (fun r acc ->
        match (r, acc) with
        | Ok x, Ok xs -> Ok (x :: xs)
        | Error e, _ -> Error e
        | _, Error e -> Error e)
      lst (Ok [])

  let parse_atoms items = items |> List.map require_atom |> sequence

  let require_field name items =
    match
      List.find_opt
        (function Sexp.List (Sexp.Atom k :: _) -> k = name | _ -> false)
        items
    with
    | Some (Sexp.List (_ :: rest)) -> Ok rest
    | Some _ -> fail (Printf.sprintf "malformed field %S" name)
    | None -> fail (Printf.sprintf "missing field %S" name)

  let parse_table items =
    let parse_row = function
      | Sexp.List row_items ->
          let* ints = row_items |> List.map require_int |> sequence in
          Ok (Array.of_list ints)
      | Sexp.Atom _ -> fail "expected list for table row, got atom"
    in
    let* rows = items |> List.map parse_row |> sequence in
    Ok (Table (Array.of_list rows))

  (* Resolves a sexp cell to a LIST index, accepting either a raw index or
     the element's own name, looked up in [names] (given in the same order
     as the corresponding parameter list). Used for performance-table /
     dynamics-table cells and, further down, for RATIO's (index-or-name
     weight) pairs, so a composer never has to remember or recompute a
     position by hand. *)
  let resolve_index_or_name unknown names = function
    | Sexp.Atom s -> (
        match int_of_string_opt s with
        | Some i -> Ok i
        | None -> (
            match
              List.assoc_opt s (names |> List.mapi (fun i name -> (name, i)))
            with
            | Some i -> Ok i
            | None -> lift (Error (unknown s))))
    | Sexp.List _ -> fail "expected atom for index or name"

  (* Same idea, but resolves against the element's own float value (for
     entrydelay/duration RATIO pairs) instead of a name. *)
  let resolve_index_or_float unknown floats = function
    | Sexp.Atom s -> (
        match int_of_string_opt s with
        | Some i -> Ok i
        | None -> (
            match float_of_string_opt s with
            | Some f -> (
                match
                  floats
                  |> List.mapi (fun i v -> (i, v))
                  |> List.find_opt (fun (_, v) -> Float.equal v f)
                with
                | Some (i, _) -> Ok i
                | None -> lift (Error (unknown s)))
            | None ->
                fail (Printf.sprintf "expected int, float, or name, got %S" s)))
    | Sexp.List _ -> fail "expected atom for index or value"

  (* performance-table / dynamics-table entries may either be raw indexes into
     the mode list (kept for backwards compatibility), or the mode names
     themselves, resolved against [names] (given in the same order as the
     parsed [perf_list] for performance, or the parsed [dyn_list] for
     dynamics) *)
  let parse_named_table unknown names items =
    let parse_row = function
      | Sexp.List row_items ->
          let* ints =
            row_items
            |> List.map (resolve_index_or_name unknown names)
            |> sequence
          in
          Ok (Array.of_list ints)
      | Sexp.Atom _ -> fail "expected list for table row, got atom"
    in
    let* rows = items |> List.map parse_row |> sequence in
    Ok (Table (Array.of_list rows))

  (* MOD-DUR / MOD-DYN / MOD-PERF's shared mode switch - see [note_mode] *)
  let parse_note_mode = function
    | [ Sexp.Atom "per-chord" ] -> Ok PerChord
    | [ Sexp.Atom "per-note" ] -> Ok PerNote
    | _ -> fail "mode expects 'per-chord' or 'per-note'"

  let parse_duration_mode = function
    | [ Sexp.List (Sexp.Atom "independent" :: m) ] ->
        let* m = parse_note_mode m in
        Ok (DurIndependent m)
    | [ Sexp.Atom "equals-entry" ] -> Ok DurEqualsEntry
    | [ Sexp.List (Sexp.Atom "shorter-than-entry" :: m) ] ->
        let* m = parse_note_mode m in
        Ok (DurShorterThanEntry m)
    | _ ->
        fail
          "duration relation expects (independent per-chord|per-note), \
           equals-entry, or (shorter-than-entry per-chord|per-note)"

  let parse_tendency_section = function
    | Sexp.List (Sexp.Atom "section" :: Sexp.Atom portion_s :: rest) -> (
        match float_of_string_opt portion_s with
        | None ->
            fail (Printf.sprintf "expected float for portion, got %S" portion_s)
        | Some portion ->
            let* start_args = require_field "start" rest in
            let* smin, smax =
              match start_args with
              | [ Sexp.Atom a; Sexp.Atom b ] ->
                  let* smin = require_float (Sexp.Atom a) in
                  let* smax = require_float (Sexp.Atom b) in
                  Ok (smin, smax)
              | _ -> fail "(start) expects two floats"
            in
            let* end_args = require_field "end" rest in
            let* emin, emax =
              match end_args with
              | [ Sexp.Atom a; Sexp.Atom b ] ->
                  let* emin = require_float (Sexp.Atom a) in
                  let* emax = require_float (Sexp.Atom b) in
                  Ok (emin, emax)
              | _ -> fail "(end) expects two floats"
            in
            let uf = UnitFloat.of_float_exn in
            Ok
              (TendencySection
                 {
                   portion;
                   start_min = uf smin;
                   start_max = uf smax;
                   end_min = uf emin;
                   end_max = uf emax;
                 }))
    | _ -> fail "expected (section portion (start f f) (end f f))"

  let parse_group_selection = function
    | Sexp.Atom "alea" -> Ok GroupAlea
    | Sexp.Atom "series" -> Ok GroupSeries
    | _ -> fail "group selector expects 'alea' or 'series'"

  let parse_ensemble_group_selection = function
    | [ Sexp.Atom "alea" ] -> Ok EnsembleGroupAlea
    | [ Sexp.Atom "series" ] -> Ok EnsembleGroupSeries
    | [ Sexp.List (Sexp.Atom "sequence" :: ints) ] ->
        let* is = ints |> List.map require_int |> sequence in
        Ok (EnsembleGroupSequence is)
    | _ ->
        fail
          "ensemble group selection expects 'alea', 'series', or (sequence \
           (...))"

  (* A non-instrument parameter's own [ensemble] field doubles as its
     combination setting: 'combination' means it has no group selection of
     its own and instead reuses whichever groups the instrument ensemble
     picked, anything else is a standalone [ensemble_group_selection]. *)
  let parse_combination = function
    | [ Sexp.Atom "combination" ] -> Ok Combination
    | args ->
        let* sel = parse_ensemble_group_selection args in
        Ok (NoCombination sel)

  (* [resolve_ratio_index] resolves the first slot of a (index-or-value
     weight) pair; it defaults to plain-int parsing (e.g. for density, whose
     range has no separate name/value form), but callers with an actual
     parameter list (instrument/entrydelay/performance/dynamics) pass a
     resolver built from that list, via [resolve_index_or_name] /
     [resolve_index_or_float], so a composer can write either the LIST
     index or the element's own name/value. *)
  let parse_principle ?(resolve_ratio_index = require_int) items =
    match items with
    | [ Sexp.Atom "alea" ] -> Ok Alea
    | [ Sexp.Atom "series" ] -> Ok Series
    | [ Sexp.List (Sexp.Atom "sequence" :: [ Sexp.List ints ]) ] ->
        let* is = ints |> List.map require_int |> sequence in
        Ok (Sequence is)
    | [ Sexp.List (Sexp.Atom "ratio" :: [ Sexp.List pairs ]) ] ->
        let parse_pair = function
          | Sexp.List [ idx; Sexp.Atom w ] ->
              let* i = resolve_ratio_index idx in
              let* w = require_int (Sexp.Atom w) in
              Ok (i, w)
          | _ -> fail "ratio pair expects (index-or-value weight)"
        in
        let* ps = pairs |> List.map parse_pair |> sequence in
        Ok (Ratio ps)
    | [ Sexp.List (Sexp.Atom "group" :: args) ] ->
        let get1_gs name =
          let* a = require_field name args in
          match a with
          | [ x ] -> parse_group_selection x
          | _ -> fail (name ^ " expects one value")
        in
        let* element = get1_gs "element" in
        let* repetition = get1_gs "repetition" in
        let* min_rep, max_rep =
          let* a = require_field "repetitions" args in
          match a with
          | [ Sexp.Atom lo; Sexp.Atom hi ] ->
              let* lo = require_int (Sexp.Atom lo) in
              let* hi = require_int (Sexp.Atom hi) in
              Ok (lo, hi)
          | _ -> fail "repetitions expects two ints"
        in
        Ok (Group (mkGroup element repetition min_rep max_rep))
    | [ Sexp.List (Sexp.Atom "tendency" :: sections) ] ->
        let* sects = sections |> List.map parse_tendency_section |> sequence in
        Ok (Tendency (TendencyMask sects))
    | _ -> fail "unknown or unsupported selection principle"

  let parse_compass items =
    match items with
    | [ Sexp.Atom "percussion" ] -> Ok PercussionCompass
    | [
     Sexp.List [ Sexp.Atom r1; Sexp.Atom p1 ];
     Sexp.List [ Sexp.Atom r2; Sexp.Atom p2 ];
    ] ->
        let* r1 = require_int (Sexp.Atom r1) in
        let* p1 = require_int (Sexp.Atom p1) in
        let* r2 = require_int (Sexp.Atom r2) in
        let* p2 = require_int (Sexp.Atom p2) in
        let* o1 = lift (mk_octave r1) in
        let* o2 = lift (mk_octave r2) in
        lift
          (mk_pitch_compass (absolute o1 (Step p1)) (absolute o2 (Step p2))
             Pitch_set.empty)
    | _ ->
        fail
          "compass expects 'percussion' or (register pitch) (register pitch)"

  (* REGISTER entries mirror compass' own (octave step) (octave step) shape
     - the two concepts share the same underlying [absolute_pitch] pair, one
     bounding an instrument's own range, the other bounding where a tone may
     be placed - plus a 'percussion' marker for [PercussionRegister]. *)
  let parse_register items =
    match items with
    | [ Sexp.Atom "percussion" ] -> Ok PercussionRegister
    | [
     Sexp.List [ Sexp.Atom r1; Sexp.Atom p1 ];
     Sexp.List [ Sexp.Atom r2; Sexp.Atom p2 ];
    ] ->
        let* r1 = require_int (Sexp.Atom r1) in
        let* p1 = require_int (Sexp.Atom p1) in
        let* r2 = require_int (Sexp.Atom r2) in
        let* p2 = require_int (Sexp.Atom p2) in
        let* o1 = lift (mk_octave r1) in
        let* o2 = lift (mk_octave r2) in
        lift (mk_register (absolute o1 (Step p1)) (absolute o2 (Step p2)))
    | _ ->
        fail
          "register expects 'percussion' or (register pitch) (register \
           pitch)"

  (* One entry of HARMONY's row (EMR-3 8.2): either a relative pitch, or the
     literal atom "p" marking a percussion event - never PR-2's 0 sentinel,
     which is now just an ordinary out-of-range relative pitch. *)
  let parse_row_item = function
    | Sexp.Atom "p" -> Ok None
    | Sexp.Atom _ as a ->
        let* n = require_int a in
        Ok (Some n)
    | Sexp.List _ -> fail "row entry expects a relative pitch or 'p'"

  let parse_instrument i sexp =
    match sexp with
    | Sexp.List (Sexp.Atom "instrument" :: Sexp.Atom name :: fields) ->
        let* instr =
          in_loc [ Key KInstrument; Index i; Key KName ] (lift (mk_instr name))
        in
        let* cs =
          in_loc
            [ Key KInstrument; Index i; Key KChordsize ]
            (let* args = require_field "chordsize" fields in
             match args with
             | [ Sexp.Atom a; Sexp.Atom b ] ->
                 let* min_v = require_int (Sexp.Atom a) in
                 let* max_v = require_int (Sexp.Atom b) in
                 lift (chordsize min_v max_v)
             | _ -> fail "chordsize expects two ints")
        in
        let* perf =
          in_loc
            [ Key KInstrument; Index i; Key KPerformance ]
            (let* items = require_field "performance" fields in
             match items with
             | [ Sexp.List inner ] ->
                 let* names = parse_atoms inner in
                 Ok
                   (names
                   |> List.map Performance.of_string
                   |> Performance_modes.of_list)
             | _ -> fail "performance expects (performance (...))")
        in
        let* dyns =
          in_loc
            [ Key KInstrument; Index i; Key KDynamics ]
            (let* items = require_field "dynamics" fields in
             match items with
             | [ Sexp.List inner ] ->
                 let* names = parse_atoms inner in
                 Ok
                   (names |> List.map Dynamic.of_string |> Dynamic_modes.of_list)
             | _ -> fail "dynamics expects (dynamics (...))")
        in
        let* compass =
          in_loc
            [ Key KInstrument; Index i; Key KCompass ]
            (let* args = require_field "compass" fields in
             parse_compass args)
        in
        let* durations =
          in_loc
            [ Key KInstrument; Index i; Key KDurations ]
            (let* args = require_field "durations" fields in
             match args with
             | [ Sexp.Atom a; Sexp.Atom b ] ->
                 let* min_v = require_float (Sexp.Atom a) in
                 let* max_v = require_float (Sexp.Atom b) in
                 lift (mk_allowed_durations min_v max_v)
             | _ -> fail "durations expects two floats")
        in
        Ok (inst instr cs perf dyns compass durations)
    | _ ->
        in_loc
          [ Key KInstrument; Index i ]
          (fail "expected (instrument name ...)")

  let parse_density items =
    match items with
    | [ Sexp.List (Sexp.Atom "autonomous" :: args) ] ->
        let get_int name =
          let* a = require_field name args in
          match a with
          | [ x ] -> require_int x
          | _ -> fail (name ^ " expects one int")
        in
        let* low_v = get_int "low" in
        let* high_v = get_int "high" in
        let* p =
          let* a = require_field "principle" args in
          parse_principle a
        in
        lift (mk_autonomous ~low:low_v ~high:high_v ~selection_principle:p)
    | [ Sexp.Atom "instrument-density" ] -> Ok InstrumentDensity
    | other ->
        fail
          (Printf.sprintf
             "density expects either\n\
             \  (autonomous (low <int>) (high <int>) (tr <int>) (principle \
              <selection-principle>))\n\
             \  or instrument-density\n\
              got: (density %s)"
             (other |> List.map sexp_to_string |> String.concat " "))

  let parse_hierarchy_elem = function
    | "Ins" -> Ok Ins
    | "Per" -> Ok Per
    | "Dyn" -> Ok Dyn
    | "Dur" -> Ok Dur
    | "Ent" -> Ok Ent
    | "Reg" -> Ok Reg
    | "Har" -> Ok Har
    | s -> fail (Printf.sprintf "unknown hierarchy element %S" s)

  let of_sexp sexps =
    let* items =
      in_loc [ Key KGlobal ]
        (match sexps with
        | [ Sexp.List (Sexp.Atom "structure-formula" :: items) ] -> Ok items
        | _ -> fail "expected top-level (structure-formula ...)")
    in
    let get1 name parse =
      let* args = require_field name items in
      match args with
      | [ x ] -> parse x
      | _ -> fail (Printf.sprintf "field %S expects one value" name)
    in
    let* seed = in_loc [ Key KGlobal; Key KSeed ] (get1 "seed" require_int) in
    let* variant_duration =
      in_loc
        [ Key KGlobal; Key KVariantDuration ]
        (get1 "variant-duration" require_float)
    in
    (* tones-per-octave (tr, EMR-3 9.3): global, since HARMONY's row and
       REGISTER's octave digit both share it. Also the GUI's existing
       "octave-division" field, so no new sexp key is introduced here. *)
    let* tr =
      in_loc [ Key KGlobal; Key KTr ] (get1 "octave-division" require_int)
    in
    let* () =
      in_loc [ Key KGlobal; Key KTr ] (lift (if tr < 1 then Error (InvalidTr tr) else Ok ()))
    in
    let* number_of_instrument_groups =
      in_loc
        [ Key KInstrument; Key KInstrumentCount ]
        (get1 "number-of-instrument-groups" require_int)
    in
    let* instr_list =
      let* args =
        in_loc
          [ Key KInstrument; Key KList ]
          (require_field "instruments" items)
      in
      let* instrs = args |> List.mapi parse_instrument |> sequence in
      Ok (ParameterList (Array.of_list instrs))
    in
    let* instr_table =
      in_loc
        [ Key KInstrument; Key KTable ]
        (let* args = require_field "instrument-table" items in
         parse_table args)
    in
    let* ed_list =
      in_loc
        [ Key KEntrydelay; Key KList ]
        (let* args = require_field "entrydelays" items in
         let* floats =
           match args with
           | [ Sexp.List inner ] -> inner |> List.map require_float |> sequence
           | _ -> fail "entrydelays expects (entrydelays (...))"
         in
         let* eds =
           floats |> List.map (fun f -> lift (mk_entrydelay f)) |> sequence
         in
         Ok (ParameterList (Array.of_list eds)))
    in
    let* ed_table =
      in_loc
        [ Key KEntrydelay; Key KTable ]
        (let* args = require_field "entrydelay-table" items in
         parse_table args)
    in
    let* dur_list =
      in_loc
        [ Key KDuration; Key KList ]
        (let* args = require_field "durations" items in
         let* floats =
           match args with
           | [ Sexp.List inner ] -> inner |> List.map require_float |> sequence
           | _ -> fail "durations expects (durations (...))"
         in
         let* durs =
           floats |> List.map (fun f -> lift (mk_duration f)) |> sequence
         in
         Ok (ParameterList (Array.of_list durs)))
    in
    let* dur_table =
      in_loc
        [ Key KDuration; Key KTable ]
        (let* args = require_field "duration-table" items in
         parse_table args)
    in
    let* perf_list =
      in_loc
        [ Key KPerformance; Key KList ]
        (let* args = require_field "performance" items in
         match args with
         | [ Sexp.List inner ] ->
             let* names = parse_atoms inner in
             Ok
               (ParameterList
                  (Array.of_list (List.map Performance.of_string names)))
         | _ -> fail "performance expects (performance (...))")
    in
    let perf_names =
      let (ParameterList perf_arr) = perf_list in
      perf_arr |> Array.to_list |> List.map Performance.to_string
    in
    let* performance_table =
      in_loc
        [ Key KPerformance; Key KTable ]
        (let* args = require_field "performance-table" items in
         parse_named_table (fun s -> UnknownPerformance s) perf_names args)
    in
    let* dyn_list =
      in_loc
        [ Key KDynamics; Key KList ]
        (let* args = require_field "dynamics" items in
         match args with
         | [ Sexp.List inner ] ->
             let* names = parse_atoms inner in
             Ok
               (ParameterList (Array.of_list (List.map Dynamic.of_string names)))
         | _ -> fail "dynamics expects (dynamics (...))")
    in
    let dyn_names =
      let (ParameterList dyn_arr) = dyn_list in
      dyn_arr |> Array.to_list |> List.map Dynamic.to_string
    in
    let* dynamics_table =
      in_loc
        [ Key KDynamics; Key KTable ]
        (let* args = require_field "dynamics-table" items in
         parse_named_table (fun s -> UnknownDynamic s) dyn_names args)
    in
    let* reg_list =
      in_loc
        [ Key KRegister; Key KList ]
        (let* args = require_field "registers" items in
         match args with
         | [ Sexp.List inner ] ->
             let* regs =
               inner
               |> List.map (function
                    | Sexp.List entry -> parse_register entry
                    | Sexp.Atom _ -> fail "expected list for register entry")
               |> sequence
             in
             Ok (ParameterList (Array.of_list regs))
         | _ -> fail "registers expects (registers (...))")
    in
    (* Registers have no natural name to reference by (unlike performance/
       dynamics modes), so register-table cells are always plain LIST
       indexes - a plain [parse_table], not [parse_named_table]. *)
    let* register_table =
      in_loc
        [ Key KRegister; Key KTable ]
        (let* args = require_field "register-table" items in
         parse_table args)
    in
    let* row, transposition, harmony_mode =
      let* args = in_loc [ Key KHarmony ] (require_field "harmony" items) in
      let* row =
        in_loc
          [ Key KHarmony; Key KRow ]
          (let* row_args = require_field "row" args in
           let* items =
             match row_args with
             | [ Sexp.List inner ] -> inner |> List.map parse_row_item |> sequence
             | _ -> fail "row expects (row (...))"
           in
           lift (mk_row ~tr items))
      in
      let* transposition =
        in_loc
          [ Key KHarmony; Key KTransposition ]
          (let* t_args = require_field "transposition" args in
           match t_args with
           | [ Sexp.Atom s ] -> lift (transposition_of_string s)
           | _ ->
               fail
                 "transposition expects one of: none, alea, series, \
                  chromatic, serial")
      in
      let* harmony_mode =
        in_loc
          [ Key KHarmony; Key KMode ]
          (let* m_args = require_field "mode" args in
           parse_note_mode m_args)
      in
      Ok (row, transposition, harmony_mode)
    in
    let instr_names =
      let (ParameterList instr_arr) = instr_list in
      instr_arr |> Array.to_list
      |> List.map (fun (Instrument { instrument = InstrumentName n; _ }) -> n)
    in
    let ed_floats =
      let (ParameterList ed_arr) = ed_list in
      ed_arr |> Array.to_list |> List.map entry_to_float
    in
    let dur_floats =
      let (ParameterList dur_arr) = dur_list in
      dur_arr |> Array.to_list |> List.map (fun (Duration f) -> f)
    in
    let* principles =
      in_loc [ Key KGlobal ] (require_field "principles" items)
    in
    (* Every non-instrument parameter's [ensemble] field doubles as its
       combination setting (see [parse_combination]); instrument has no
       combination concept of its own (there's nothing for it to reuse
       groups from), so it's parsed separately below via
       [parse_ensemble_group_selection] directly. [key_to_string key] doubles
       as the sexp field name to look up, since they coincide for every
       parameter kind this is used for (entrydelay/performance/dynamics). *)
    let parse_param_principles ?resolve_ratio_index (key : key) =
      let name = key_to_string key in
      let* args = in_loc [ Key key ] (require_field name principles) in
      let* ens =
        in_loc
          [ Key key; Key KCombination ]
          (let* ens_args = require_field "ensemble" args in
           parse_combination ens_args)
      in
      let* samp =
        in_loc
          [ Key key; Key KPrinciple ]
          (let* samp_args = require_field "order" args in
           parse_principle ?resolve_ratio_index samp_args)
      in
      Ok (ens, samp)
    in
    let parse_principle_mode (key : key) =
      let name = key_to_string key in
      in_loc [ Key key; Key KMode ]
        (let* args = require_field name principles in
         let* margs = require_field "mode" args in
         parse_note_mode margs)
    in
    let* instr_ensemble_group_selection, instrument_principle =
      let* args =
        in_loc [ Key KInstrument ] (require_field "instrument" principles)
      in
      let* ens =
        in_loc
          [ Key KInstrument; Key KCombination ]
          (let* ens_args = require_field "ensemble" args in
           parse_ensemble_group_selection ens_args)
      in
      let* samp =
        in_loc
          [ Key KInstrument; Key KPrinciple ]
          (let* samp_args = require_field "order" args in
           parse_principle
             ~resolve_ratio_index:
               (resolve_index_or_name
                  (fun s ->
                    ParseError (Printf.sprintf "unknown instrument %S" s))
                  instr_names)
             samp_args)
      in
      Ok (ens, samp)
    in
    let* entrydelay_combination, entrydelay_principle =
      parse_param_principles KEntrydelay
        ~resolve_ratio_index:
          (resolve_index_or_float
             (fun s -> ParseError (Printf.sprintf "unknown entrydelay %S" s))
             ed_floats)
    in
    let* performance_combination, performance_principle =
      parse_param_principles KPerformance
        ~resolve_ratio_index:
          (resolve_index_or_name (fun s -> UnknownPerformance s) perf_names)
    in
    let* performance_mode = parse_principle_mode KPerformance in
    let* dynamics_combination, dynamics_principle =
      parse_param_principles KDynamics
        ~resolve_ratio_index:
          (resolve_index_or_name (fun s -> UnknownDynamic s) dyn_names)
    in
    let* dynamics_mode = parse_principle_mode KDynamics in
    let* register_combination, register_principle =
      parse_param_principles KRegister
    in
    let* register_mode = parse_principle_mode KRegister in
    let* duration_combination, duration_principle, duration_relation_mode =
      let* args =
        in_loc [ Key KDuration ] (require_field "duration" principles)
      in
      let* ens =
        in_loc
          [ Key KDuration; Key KCombination ]
          (let* ens_args = require_field "ensemble" args in
           parse_combination ens_args)
      in
      let* samp =
        in_loc
          [ Key KDuration; Key KPrinciple ]
          (let* samp_args = require_field "order" args in
           parse_principle
             ~resolve_ratio_index:
               (resolve_index_or_float
                  (fun s -> ParseError (Printf.sprintf "unknown duration %S" s))
                  dur_floats)
             samp_args)
      in
      let* rel =
        in_loc
          [ Key KDuration; Key KRelation ]
          (let* rel_args = require_field "relation" args in
           parse_duration_mode rel_args)
      in
      Ok (ens, samp, rel)
    in
    let* union =
      in_loc [ Key KUnion ]
        (let* args = require_field "union" items in
         match args with
         | [ Sexp.Atom "none" ] -> Ok NoUnion
         | [ Sexp.Atom "union" ] -> Ok Union
         | _ -> fail "union expects 'none' or 'union'")
    in
    let* density =
      in_loc [ Key KDensity ]
        (let* args = require_field "density" items in
         parse_density args)
    in
    let* hierarchy =
      in_loc [ Key KHierarchy ]
        (let* args = require_field "hierarchy" items in
         let* elems =
           match args with
           | [ Sexp.List inner ] ->
               let* names = parse_atoms inner in
               names |> List.map parse_hierarchy_elem |> sequence
           | _ -> fail "hierarchy expects (hierarchy (...))"
         in
         lift (mk_hierarchy elems))
    in
    mk_structure_formula ~seed ~variant_duration ~instr_list ~instr_table
      ~instr_ensemble_group_selection ~number_of_instrument_groups ~ed_list
      ~ed_table ~perf_list ~performance_table ~dyn_list ~dynamics_table
      ~entrydelay_combination ~instrument_principle ~entrydelay_principle
      ~performance_principle ~performance_combination ~performance_mode
      ~dynamics_principle ~dynamics_combination ~dynamics_mode ~reg_list
      ~register_table ~register_principle ~register_combination
      ~register_mode ~row ~tr ~transposition ~harmony_mode ~union ~density
      ~hierarchy ~dur_list ~dur_table ~duration_combination
      ~duration_relation_mode ~duration_principle

  let read_file path =
    let ic = open_in path in
    let content =
      let n = in_channel_length ic in
      let s = Bytes.create n in
      really_input ic s 0 n;
      close_in ic;
      Bytes.to_string s
    in
    match Sexp.of_string content with
    | Error e ->
        Error
          ( [
              {
                location = [ Key KGlobal ];
                severity = Severity.Error;
                problem = ParseError e;
              };
            ],
            [] )
    | Ok sexps -> of_sexp sexps
end
