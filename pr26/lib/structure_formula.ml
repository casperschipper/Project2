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
  (* N-VARIANTS (EMR-3 9.8): how many variants to calculate in this run
     ("variant group"), all sharing one continuing selection-cycle state -
     see [Score_generation.build_score]. *)
  n_variants : int;
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
  (* HARMONY (EMR-3 8.2): ROW and INTERVAL, its two "row principles" (CHORD
     is out of scope, see harmony.md - it becomes main parameter and takes
     over vertical density itself, a fundamentally different mechanism).
     Neither has ensemble machinery - each is its own bespoke stream rather
     than an Alea/Series/Tendency draw - and neither has a "per chord" mode:
     both always distribute one value per chord tone. *)
  harmony : harmony_principle;
  tr : int;
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

let mk_structure_formula ~seed ~variant_duration ~n_variants ~instr_list
    ~instr_table ~instr_ensemble_group_selection ~ed_list ~ed_table
    ~number_of_instrument_groups ~perf_list ~performance_table ~dyn_list
    ~dynamics_table ~entrydelay_combination ~instrument_principle
    ~entrydelay_principle ~performance_principle ~performance_combination
    ~performance_mode ~dynamics_principle ~dynamics_combination ~dynamics_mode
    ~reg_list ~register_table ~register_principle ~register_combination
    ~register_mode ~harmony ~tr ~union ~hierarchy
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
    | ChordDensity, first :: _ ->
        if first == Har then []
        else
          [
            {
              location = [ Key KHierarchy ];
              severity = Severity.Error;
              problem = HarmonyRequiresHarFirst;
            };
          ]
    | _ -> []
  in
  (* CHORD makes HARMONY the main parameter and thus decisive for vertical
     density (EMR-3 §9.2) - the two settings must always agree, in both
     directions, so a composer changing one without the other is caught
     immediately rather than silently doing the wrong thing at runtime. *)
  let chord_density_consistency_errors =
    match (harmony, density) with
    | HarmChord _, ChordDensity -> []
    | HarmChord _, _ ->
        [
          {
            location = [ Key KDensity ];
            severity = Severity.Error;
            problem = ChordPrincipleDensityMismatch;
          };
        ]
    | (HarmRow _ | HarmInterval _), ChordDensity ->
        [
          {
            location = [ Key KHarmony; Key KPrinciple ];
            severity = Severity.Error;
            problem = ChordPrincipleDensityMismatch;
          };
        ]
    | (HarmRow _ | HarmInterval _), (Autonomous _ | InstrumentDensity) -> []
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
    let needs_ins_first_always location elem =
      match (hierarchy_index Ins, hierarchy_index elem) with
      | Some ins_i, Some elem_i when elem_i < ins_i ->
          [
            {
              location;
              severity = Severity.Error;
              problem = PerNoteRequiresInsFirst;
            };
          ]
      | _ -> []
    in
    let needs_ins_first location elem = function
      | PerChord -> []
      | PerNote -> needs_ins_first_always location elem
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
    (* ROW/INTERVAL always distribute per chord tone (no "per chord" mode of
       their own), so they always need the chord's instrument - and thus its
       note count - resolved first. CHORD is the opposite: it decides the
       chord (and hence the note count) itself, so Ins must come *after* Har
       - enforced separately, by [hierarchy_errors] above via
       [HarmonyRequiresHarFirst], not here. *)
    @ (match harmony with
      | HarmRow _ | HarmInterval _ -> needs_ins_first_always [ Key KHarmony ] Har
      | HarmChord _ -> [])
  in
  (* Fig. 8-5's own well-formedness caution: a row with no allowed successor
     at all is a genuine dead end - the composer's to avoid, not something
     the runtime repairs (though it degrades gracefully if reached anyway -
     see [Score_generation]'s "INTERVAL RESTRICTIONS TOO STRICT"). *)
  let interval_matrix_warnings =
    match harmony with
    | HarmInterval { matrix; _ } ->
        interval_matrix_dead_end_rows matrix
        |> List.map (fun i ->
               {
                 location = [ Key KHarmony; Key KMatrix; Index (i - 1) ];
                 severity = Severity.Warning;
                 problem = IntervalMatrixRowHasNoSuccessor i;
               })
    | HarmRow _ | HarmChord _ -> []
  in
  (* EMR-3 §8.2: "Maximum number of tones per group = pitch grid tr." *)
  let chord_table_errors =
    match harmony with
    | HarmChord { table; _ } ->
        chord_table_too_long_indices ~tr table
        |> List.map (fun (i, len) ->
               {
                 location = [ Key KHarmony; Key KChord; Index i ];
                 severity = Severity.Error;
                 problem = ChordTooLong { len; tr };
               })
    | HarmRow _ | HarmInterval _ -> []
  in
  let all_diags =
    hierarchy_errors @ chord_density_consistency_errors @ combination_errors
    @ performance_membership_errors @ dynamics_membership_errors
    @ ratio_coverage_errors @ per_note_ordering_errors
    @ interval_matrix_warnings @ chord_table_errors
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
            n_variants;
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
            harmony;
            tr;
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

  (* Like [require_field], but absence isn't an error - [default] is used
     instead, matching how e.g. n-variants defaults for formulas written
     before a field existed. *)
  let optional_field name ~default items parse =
    match
      List.find_opt
        (function Sexp.List (Sexp.Atom k :: _) -> k = name | _ -> false)
        items
    with
    | None -> Ok default
    | Some (Sexp.List (_ :: rest)) -> parse rest
    | Some _ -> fail (Printf.sprintf "malformed field %S" name)

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

  (* Shared grammar rule for (pitch-range ...): the same sub-form appears
     both as an instrument's own field and as each entry of REGISTER's own
     list - one bounding an instrument's own range, the other bounding where
     a tone may be placed. [items] is the body *after* the "pitch-range"
     keyword has already been stripped by the caller. Returns [None] for
     percussion so each call site maps onto its own percussion variant
     ([PercussionPitchRange] / [PercussionRegister]). *)
  let parse_pitch_range_body items =
    match items with
    | [ Sexp.Atom "percussion" ] -> Ok None
    | _ ->
        let parse_bound name =
          let* args = require_field name items in
          match args with
          | [
           Sexp.List [ Sexp.Atom "octave"; oct ];
           Sexp.List [ Sexp.Atom "pitch"; p ];
          ] ->
              let* o = require_int oct in
              let* p = require_int p in
              let* o = lift (mk_octave o) in
              Ok (absolute o (Step p))
          | _ -> fail (Printf.sprintf "%s expects (octave N) (pitch N)" name)
        in
        let* low = parse_bound "low" in
        let* high = parse_bound "high" in
        Ok (Some (low, high))

  let parse_instrument_pitch_range items =
    let* range = parse_pitch_range_body items in
    match range with
    | None -> Ok PercussionPitchRange
    | Some (min, max) -> lift (mk_pitch_range min max Pitch_set.empty)

  (* One REGISTER-list entry is a standalone (pitch-range ...) form (unlike
     the instrument field, which lives inside a fields list), so this strips
     the leading keyword itself before delegating to the shared body
     parser above. *)
  let parse_register_entry = function
    | Sexp.List (Sexp.Atom "pitch-range" :: rest) ->
        let* range = parse_pitch_range_body rest in
        (match range with
        | None -> Ok PercussionRegister
        | Some (low, high) -> lift (mk_register low high))
    | Sexp.List _ | Sexp.Atom _ -> fail "register entry expects (pitch-range ...)"

  (* One entry of HARMONY's row (EMR-3 8.2): either a relative pitch, or the
     literal atom "p" marking a percussion event - never PR-2's 0 sentinel,
     which is now just an ordinary out-of-range relative pitch. *)
  let parse_row_item = function
    | Sexp.Atom "p" -> Ok None
    | Sexp.Atom _ as a ->
        let* n = require_int a in
        Ok (Some n)
    | Sexp.List _ -> fail "row entry expects a relative pitch or 'p'"

  (* One entry of HARMONY's CHORD table (EMR-3 8.2): a whole chord, i.e. a
     list of relative-pitch-or-"p" entries, each parsed exactly like one
     ROW entry above. *)
  let parse_chord_entry = function
    | Sexp.List items -> items |> List.map parse_row_item |> sequence
    | Sexp.Atom _ -> fail "expected a list of pitches for one chord"

  (* TRANSP-CHORD, entry 18: like TRANSP-ROW, but only 4 forms - the
     composer-given "row" (option 3) is a distinct, separately-authored
     list, so it needs its own leading keyword ("given") to disambiguate
     from the bare-atom forms, matching how (matrix (rows ...)) vs
     (matrix (chord ...)) already disambiguate sub-forms elsewhere. *)
  let parse_chord_transposition ~tr = function
    | [ Sexp.Atom "none" ] -> Ok ChordNoTransposition
    | [ Sexp.Atom "alea" ] -> Ok ChordTransposeAlea
    | [ Sexp.Atom "series" ] -> Ok ChordTransposeSeries
    | [ Sexp.List (Sexp.Atom "given" :: [ Sexp.List ints ]) ] ->
        let* ns = ints |> List.map require_int |> sequence in
        lift (mk_chord_transposition_given ~tr ns)
    | _ -> fail "transposition expects one of: none, alea, series, (given (...))"

  (* HARMONY's INTERVAL principle (EMR-3 8.2, entries 21-24): the matrix can
     be authored three ways - a dense grid of 0/1 rows, derived from a given
     chord's own interval content (CHORD-INT), or a sparse adjacency list
     (given interval -> its allowed successors, not in the manual but far
     more practical to hand-write than a mostly-forbidden dense grid). *)
  let parse_interval_matrix ~tr args =
    match args with
    | [ Sexp.List (Sexp.Atom "rows" :: [ Sexp.List row_sexps ]) ] ->
        let parse_bool_row = function
          | Sexp.List cells ->
              let* ints = cells |> List.map require_int |> sequence in
              Ok (Array.of_list (List.map (fun n -> n <> 0) ints))
          | Sexp.Atom _ -> fail "expected list for matrix row, got atom"
        in
        let* rows = row_sexps |> List.map parse_bool_row |> sequence in
        lift (mk_interval_matrix ~tr (Array.of_list rows))
    | [ Sexp.List (Sexp.Atom "chord" :: [ Sexp.List tone_sexps ]) ] ->
        let* ns = tone_sexps |> List.map require_int |> sequence in
        let* steps = ns |> List.map (fun n -> lift (mk_step ~tr n)) |> sequence in
        lift (matrix_of_chord ~tr (Array.of_list steps))
    | [ Sexp.List (Sexp.Atom "adjacency" :: entries) ] ->
        let parse_entry = function
          | Sexp.List [ (Sexp.Atom _ as g); Sexp.List succs ] ->
              let* given = require_int g in
              let* succ_ints = succs |> List.map require_int |> sequence in
              Ok (given, succ_ints)
          | _ -> fail "adjacency entry expects (given (succ ...))"
        in
        let* entries = entries |> List.map parse_entry |> sequence in
        lift (mk_interval_matrix_from_adjacency ~tr entries)
    | _ ->
        fail
          "matrix expects one of: (rows (...)), (chord (...)), (adjacency \
           (given (succ ...)) ...)"

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
        let* pitchrange =
          in_loc
            [ Key KInstrument; Index i; Key KPitchRange ]
            (let* args = require_field "pitch-range" fields in
             parse_instrument_pitch_range args)
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
        Ok (inst instr cs perf dyns pitchrange durations)
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
    | [ Sexp.Atom "chord-density" ] -> Ok ChordDensity
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
    (* N-VARIANTS (EMR-3 9.8): optional, defaulting to 1 - existing formulas
       written before this field existed still mean exactly what they always
       meant, one variant. *)
    let* n_variants =
      in_loc [ Key KGlobal; Key KNVariants ]
        (match
           List.find_opt
             (function
               | Sexp.List (Sexp.Atom k :: _) -> k = "n-variants"
               | _ -> false)
             items
         with
        | None -> Ok 1
        | Some (Sexp.List [ _; x ]) -> require_int x
        | Some _ -> fail "n-variants expects one integer")
    in
    let* () =
      in_loc [ Key KGlobal; Key KNVariants ]
        (lift
           (if n_variants < 1 then Error (InvalidNVariants n_variants)
            else Ok ()))
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
             let* regs = inner |> List.map parse_register_entry |> sequence in
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
    let* harmony =
      let* args = in_loc [ Key KHarmony ] (require_field "harmony" items) in
      let* principle_name =
        in_loc [ Key KHarmony; Key KPrinciple ]
          (let* p_args = require_field "principle" args in
           match p_args with
           | [ Sexp.Atom s ] -> Ok s
           | _ -> fail "principle expects one of: row, interval")
      in
      match principle_name with
      | "row" ->
          let* row =
            in_loc
              [ Key KHarmony; Key KRow ]
              (let* row_args = require_field "row" args in
               let* items =
                 match row_args with
                 | [ Sexp.List inner ] ->
                     inner |> List.map parse_row_item |> sequence
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
          (* ROW always distributes per chord tone, no "per chord" mode of
             its own - a lingering (mode ...) field from an older file is
             simply ignored rather than parsed. *)
          Ok (HarmRow { row; transposition })
      | "interval" ->
          let* matrix =
            in_loc [ Key KHarmony; Key KMatrix ]
              (let* m_args = require_field "matrix" args in
               parse_interval_matrix ~tr m_args)
          in
          let* forbidden_ints =
            in_loc [ Key KHarmony; Key KForbiddenTones ]
              (optional_field "forbidden-tones" ~default:[] args (function
                | [ Sexp.List inner ] ->
                    inner |> List.map require_int |> sequence
                | [] -> Ok []
                | _ -> fail "forbidden-tones expects (forbidden-tones (...))"))
          in
          let* forbidden_tones =
            in_loc [ Key KHarmony; Key KForbiddenTones ]
              (let* steps =
                 forbidden_ints
                 |> List.map (fun n -> lift (mk_step ~tr n))
                 |> sequence
               in
               lift (mk_forbidden_tones ~tr steps))
          in
          let* invert =
            in_loc [ Key KHarmony; Key KInvertMatrix ]
              (optional_field "invert-matrix" ~default:false args (function
                | [ Sexp.Atom "yes" ] -> Ok true
                | [ Sexp.Atom "no" ] -> Ok false
                | _ -> fail "invert-matrix expects yes or no"))
          in
          let matrix = if invert then invert_matrix matrix else matrix in
          Ok (HarmInterval { matrix; forbidden_tones })
      | "chord" ->
          let* table =
            in_loc [ Key KHarmony; Key KChord ]
              (let* c_args = require_field "chords" args in
               match c_args with
               | [ Sexp.List chord_sexps ] ->
                   let* chords =
                     chord_sexps |> List.map parse_chord_entry |> sequence
                   in
                   lift (mk_chord_table ~tr chords)
               | _ -> fail "chords expects (chords ((...) (...) ...))")
          in
          let* order =
            in_loc [ Key KHarmony; Key KOrder ]
              (let* o_args = require_field "order" args in
               parse_principle o_args)
          in
          let* transposition =
            in_loc
              [ Key KHarmony; Key KTransposition ]
              (let* t_args = require_field "transposition" args in
               parse_chord_transposition ~tr t_args)
          in
          Ok (HarmChord { table; order; transposition })
      | s ->
          in_loc [ Key KHarmony; Key KPrinciple ] (lift (Error (IntervalPrincipleName s)))
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
    mk_structure_formula ~seed ~variant_duration ~n_variants ~instr_list
      ~instr_table ~instr_ensemble_group_selection ~number_of_instrument_groups
      ~ed_list
      ~ed_table ~perf_list ~performance_table ~dyn_list ~dynamics_table
      ~entrydelay_combination ~instrument_principle ~entrydelay_principle
      ~performance_principle ~performance_combination ~performance_mode
      ~dynamics_principle ~dynamics_combination ~dynamics_mode ~reg_list
      ~register_table ~register_principle ~register_combination
      ~register_mode ~harmony ~tr ~union ~density
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
