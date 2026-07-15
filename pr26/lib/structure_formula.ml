open Parameters
open Selection
open Tools

type combination =
  | Combination
  (* index of combined parameters is the same as instrument parameter 
  It can also be multiple groups within one ensemble, if there are multiple instrument groups*)
  | NoCombination
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
   either selected once for the whole chord (all tones at one entry point
   share it), or independently per tone. *)
type tone_mode = PerChord | PerTone

type duration_mode =
  | DurIndependent of tone_mode (* mode 0 *)
  | DurEqualsEntry (* mode 1, implies PerChord (MOD-DUR must be 0 per the manual) *)
  | DurShorterThanEntry of tone_mode
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
  ent_ensemble_group_selection : ensemble_group_selection;
  dur_list : duration parameter_list;
  dur_table : ptable;
  dur_ensemble_group_selection : ensemble_group_selection;
  duration_combination : combination;
  duration_relation_mode : duration_mode;
  duration_principle : selection_principle;
  perf_list : Performance.t parameter_list;
  performance_table : ptable;
  perf_ensemble_group_selection : ensemble_group_selection;
  dyn_list : Dynamic.t parameter_list;
  dynamics_table : ptable;
  dyn_ensemble_group_selection : ensemble_group_selection;
  instrument_principle : selection_principle;
  entrydelay_principle : selection_principle;
  entrydelay_combination : combination;
  performance_principle : selection_principle;
  performance_combination : combination;
  performance_mode : tone_mode;
  dynamics_principle : selection_principle;
  dynamics_combination : combination;
  dynamics_mode : tone_mode;
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
    ~ent_ensemble_group_selection ~number_of_instrument_groups ~perf_list
    ~performance_table ~perf_ensemble_group_selection ~dyn_list
    ~dynamics_table ~dyn_ensemble_group_selection ~entrydelay_combination
    ~instrument_principle ~entrydelay_principle ~performance_principle
    ~performance_combination ~performance_mode ~dynamics_principle
    ~dynamics_combination ~dynamics_mode ~union ~hierarchy ~density ~dur_list
    ~dur_table ~duration_combination ~dur_ensemble_group_selection
    ~duration_relation_mode ~duration_principle =
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
    @ check_combination "dynamics" instr_table dynamics_table
        dynamics_combination
    @ check_combination "duration" instr_table dur_table duration_combination
  in
  let (ParameterList instr_arr) = instr_list in
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
    check_ratio_coverage "instrument" instr_table instrument_principle
    @ check_ratio_coverage "entrydelay" ed_table entrydelay_principle
    @ check_ratio_coverage "performance" performance_table performance_principle
    @ check_ratio_coverage "dynamics" dynamics_table dynamics_principle
    @ check_ratio_coverage "duration" dur_table duration_principle
    @
    match density with
    | Autonomous { low; high; selection_principle = Ratio _ as p } ->
        let dens_table =
          Table [| Array.init (high - low + 1) (fun i -> i) |]
        in
        check_ratio_coverage "density" dens_table p
    | _ -> []
  in
  (* chordsize (number of tones) is only known once an instrument has been
     picked, so a per-tone parameter needs Ins to have already run *)
  let hierarchy_index elem =
    hierarchy |> List.mapi (fun i e -> (i, e))
    |> List.find_opt (fun (_, e) -> e = elem)
    |> Option.map fst
  in
  let per_tone_ordering_errors =
    let needs_ins_first label elem = function
      | PerChord -> []
      | PerTone -> (
          match (hierarchy_index Ins, hierarchy_index elem) with
          | Some ins_i, Some elem_i when elem_i < ins_i ->
              [
                PerToneRequiresInsFirst
                  (Printf.sprintf
                     "%s is per-tone: Ins must precede it in the hierarchy \
                      (chord size isn't known until an instrument is picked)"
                     label);
              ]
          | _ -> [])
    in
    let dur_tone_mode =
      match duration_relation_mode with
      | DurIndependent m | DurShorterThanEntry m -> m
      | DurEqualsEntry -> PerChord
    in
    needs_ins_first "performance" Per performance_mode
    @ needs_ins_first "dynamics" Dyn dynamics_mode
    @ needs_ins_first "duration" Dur dur_tone_mode
  in
  match
    hierarchy_errors @ combination_errors @ performance_membership_errors
    @ dynamics_membership_errors @ ratio_coverage_errors
    @ per_tone_ordering_errors
  with
  | [] ->
      Ok
        {
          seed;
          variant_duration;
          instr_list;
          instr_table;
          instr_ensemble_group_selection;
          ed_list;
          ed_table;
          ent_ensemble_group_selection;
          number_of_instrument_groups;
          perf_list;
          performance_table;
          perf_ensemble_group_selection;
          dyn_list;
          dynamics_table;
          dyn_ensemble_group_selection;
          entrydelay_combination;
          instrument_principle;
          entrydelay_principle;
          performance_principle;
          performance_combination;
          performance_mode;
          dynamics_principle;
          dynamics_combination;
          dynamics_mode;
          union;
          density;
          hierarchy;
          dur_list;
          dur_table;
          dur_ensemble_group_selection;
          duration_relation_mode;
          duration_principle;
          duration_combination;
        }
  | errs -> Error errs

(* structure formula AST parsers *)

module Parse = struct
  let ( let* ) = Result.bind
  let fail msg = Error [ ParseError msg ]
  let lift r = Result.map_error (fun e -> [ e ]) r

  let rec sexp_to_string = function
    | Sexp.Atom s -> s
    | Sexp.List items ->
        "(" ^ (items |> List.map sexp_to_string |> String.concat " ") ^ ")"

  let require_float = function
    | Sexp.Atom s -> (
        match float_of_string_opt s with
        | Some f -> Ok f
        | None -> fail (Printf.sprintf "expected float, got %S" s))
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
                fail (Printf.sprintf "expected int, float, or name, got %S" s)
            ))
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
            row_items |> List.map (resolve_index_or_name unknown names)
            |> sequence
          in
          Ok (Array.of_list ints)
      | Sexp.Atom _ -> fail "expected list for table row, got atom"
    in
    let* rows = items |> List.map parse_row |> sequence in
    Ok (Table (Array.of_list rows))

  let parse_combination = function
    | [ Sexp.Atom "none" ] -> Ok NoCombination
    | [ Sexp.Atom "combination" ] -> Ok Combination
    | _ -> fail "expected 'none' or 'combination'"

  (* MOD-DUR / MOD-DYN / MOD-PERF's shared mode switch - see [tone_mode] *)
  let parse_tone_mode = function
    | [ Sexp.Atom "per-chord" ] -> Ok PerChord
    | [ Sexp.Atom "per-tone" ] -> Ok PerTone
    | _ -> fail "mode expects 'per-chord' or 'per-tone'"

  let parse_duration_mode = function
    | [ Sexp.List (Sexp.Atom "independent" :: m) ] ->
        let* m = parse_tone_mode m in
        Ok (DurIndependent m)
    | [ Sexp.Atom "equals-entry" ] -> Ok DurEqualsEntry
    | [ Sexp.List (Sexp.Atom "shorter-than-entry" :: m) ] ->
        let* m = parse_tone_mode m in
        Ok (DurShorterThanEntry m)
    | _ ->
        fail
          "duration relation expects (independent per-chord|per-tone), \
           equals-entry, or (shorter-than-entry per-chord|per-tone)"

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
    | [
     Sexp.List [ Sexp.Atom r1; Sexp.Atom p1 ];
     Sexp.List [ Sexp.Atom r2; Sexp.Atom p2 ];
    ] ->
        let* r1 = require_int (Sexp.Atom r1) in
        let* p1 = require_int (Sexp.Atom p1) in
        let* r2 = require_int (Sexp.Atom r2) in
        let* p2 = require_int (Sexp.Atom p2) in
        lift
          (mk_pitch_compass
             (absolute (Register r1) p1)
             (absolute (Register r2) p2)
             Pitch_set.empty)
    | _ -> fail "compass expects (register pitch) (register pitch)"

  let parse_instrument = function
    | Sexp.List (Sexp.Atom "instrument" :: Sexp.Atom name :: fields) ->
        let* instr = lift (mk_instr name) in
        let* cs =
          let* args = require_field "chordsize" fields in
          match args with
          | [ Sexp.Atom a; Sexp.Atom b ] ->
              let* min_v = require_int (Sexp.Atom a) in
              let* max_v = require_int (Sexp.Atom b) in
              lift (chordsize min_v max_v)
          | _ -> fail "chordsize expects two ints"
        in
        let* perf =
          let* items = require_field "performance" fields in
          match items with
          | [ Sexp.List inner ] ->
              let* names = parse_atoms inner in
              Ok
                (names
                |> List.map Performance.of_string
                |> Performance_modes.of_list)
          | _ -> fail "performance expects (performance (...))"
        in
        let* dyns =
          let* items = require_field "dynamics" fields in
          match items with
          | [ Sexp.List inner ] ->
              let* names = parse_atoms inner in
              Ok (names |> List.map Dynamic.of_string |> Dynamic_modes.of_list)
          | _ -> fail "dynamics expects (dynamics (...))"
        in
        let* compass =
          let* args = require_field "compass" fields in
          parse_compass args
        in
        let* durations =
          let* args = require_field "durations" fields in
          match args with
          | [ Sexp.Atom a; Sexp.Atom b ] ->
              let* min_v = require_float (Sexp.Atom a) in
              let* max_v = require_float (Sexp.Atom b) in
              lift (mk_allowed_durations min_v max_v)
          | _ -> fail "durations expects two floats"
        in
        Ok (inst instr cs perf dyns compass durations)
    | _ -> fail "expected (instrument name ...)"

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
    | s -> fail (Printf.sprintf "unknown hierarchy element %S" s)

  let of_sexp sexps =
    let* items =
      match sexps with
      | [ Sexp.List (Sexp.Atom "structure-formula" :: items) ] -> Ok items
      | _ -> fail "expected top-level (structure-formula ...)"
    in
    let get1 name parse =
      let* args = require_field name items in
      match args with
      | [ x ] -> parse x
      | _ -> fail (Printf.sprintf "field %S expects one value" name)
    in
    let* seed = get1 "seed" require_int in
    let* variant_duration = get1 "variant-duration" require_float in
    let* number_of_instrument_groups =
      get1 "number-of-instrument-groups" require_int
    in
    let* instr_list =
      let* args = require_field "instruments" items in
      let* instrs = args |> List.map parse_instrument |> sequence in
      Ok (ParameterList (Array.of_list instrs))
    in
    let* instr_table =
      let* args = require_field "instrument-table" items in
      parse_table args
    in
    let* ed_list =
      let* args = require_field "entrydelays" items in
      let* floats =
        match args with
        | [ Sexp.List inner ] -> inner |> List.map require_float |> sequence
        | _ -> fail "entrydelays expects (entrydelays (...))"
      in
      let* eds =
        floats |> List.map (fun f -> lift (mk_entrydelay f)) |> sequence
      in
      Ok (ParameterList (Array.of_list eds))
    in
    let* ed_table =
      let* args = require_field "entrydelay-table" items in
      parse_table args
    in
    let* dur_list =
      let* args = require_field "durations" items in
      let* floats =
        match args with
        | [ Sexp.List inner ] -> inner |> List.map require_float |> sequence
        | _ -> fail "durations expects (durations (...))"
      in
      let* durs =
        floats |> List.map (fun f -> lift (mk_duration f)) |> sequence
      in
      Ok (ParameterList (Array.of_list durs))
    in
    let* dur_table =
      let* args = require_field "duration-table" items in
      parse_table args
    in
    let* perf_list =
      let* args = require_field "performance" items in
      match args with
      | [ Sexp.List inner ] ->
          let* names = parse_atoms inner in
          Ok
            (ParameterList (Array.of_list (List.map Performance.of_string names)))
      | _ -> fail "performance expects (performance (...))"
    in
    let perf_names =
      let (ParameterList perf_arr) = perf_list in
      perf_arr |> Array.to_list |> List.map Performance.to_string
    in
    let* performance_table =
      let* args = require_field "performance-table" items in
      parse_named_table (fun s -> UnknownPerformance s) perf_names args
    in
    let* dyn_list =
      let* args = require_field "dynamics" items in
      match args with
      | [ Sexp.List inner ] ->
          let* names = parse_atoms inner in
          Ok (ParameterList (Array.of_list (List.map Dynamic.of_string names)))
      | _ -> fail "dynamics expects (dynamics (...))"
    in
    let dyn_names =
      let (ParameterList dyn_arr) = dyn_list in
      dyn_arr |> Array.to_list |> List.map Dynamic.to_string
    in
    let* dynamics_table =
      let* args = require_field "dynamics-table" items in
      parse_named_table (fun s -> UnknownDynamic s) dyn_names args
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
    let* principles = require_field "principles" items in
    let parse_param_principles ?resolve_ratio_index name =
      let* args = require_field name principles in
      let* ens_args = require_field "ensemble" args in
      let* ens = parse_ensemble_group_selection ens_args in
      let* samp_args = require_field "sample" args in
      let* samp = parse_principle ?resolve_ratio_index samp_args in
      Ok (ens, samp)
    in
    let parse_principle_mode name =
      let* args = require_field name principles in
      let* margs = require_field "mode" args in
      parse_tone_mode margs
    in
    let* instr_ensemble_group_selection, instrument_principle =
      parse_param_principles "instrument"
        ~resolve_ratio_index:
          (resolve_index_or_name
             (fun s -> ParseError (Printf.sprintf "unknown instrument %S" s))
             instr_names)
    in
    let* ent_ensemble_group_selection, entrydelay_principle =
      parse_param_principles "entrydelay"
        ~resolve_ratio_index:
          (resolve_index_or_float
             (fun s -> ParseError (Printf.sprintf "unknown entrydelay %S" s))
             ed_floats)
    in
    let* perf_ensemble_group_selection, performance_principle =
      parse_param_principles "performance"
        ~resolve_ratio_index:
          (resolve_index_or_name (fun s -> UnknownPerformance s) perf_names)
    in
    let* performance_mode = parse_principle_mode "performance" in
    let* dyn_ensemble_group_selection, dynamics_principle =
      parse_param_principles "dynamics"
        ~resolve_ratio_index:
          (resolve_index_or_name (fun s -> UnknownDynamic s) dyn_names)
    in
    let* dynamics_mode = parse_principle_mode "dynamics" in
    let* dur_ensemble_group_selection, duration_principle =
      parse_param_principles "duration"
        ~resolve_ratio_index:
          (resolve_index_or_float
             (fun s -> ParseError (Printf.sprintf "unknown duration %S" s))
             dur_floats)
    in
    let* combination = require_field "combination" items in
    let* entrydelay_combination =
      let* args = require_field "entrydelay" combination in
      parse_combination args
    in
    let* performance_combination =
      let* args = require_field "performance" combination in
      parse_combination args
    in
    let* dynamics_combination =
      let* args = require_field "dynamics" combination in
      parse_combination args
    in
    let* duration_combination =
      let* args = require_field "duration" combination in
      parse_combination args
    in
    let* duration_relation_mode =
      let* args = require_field "duration-relation" items in
      parse_duration_mode args
    in
    let* union =
      let* args = require_field "union" items in
      match args with
      | [ Sexp.Atom "none" ] -> Ok NoUnion
      | [ Sexp.Atom "union" ] -> Ok Union
      | _ -> fail "union expects 'none' or 'union'"
    in
    let* density =
      let* args = require_field "density" items in
      parse_density args
    in
    let* hierarchy =
      let* args = require_field "hierarchy" items in
      let* elems =
        match args with
        | [ Sexp.List inner ] ->
            let* names = parse_atoms inner in
            names |> List.map parse_hierarchy_elem |> sequence
        | _ -> fail "hierarchy expects (hierarchy (...))"
      in
      lift (mk_hierarchy elems)
    in
    mk_structure_formula ~seed ~variant_duration ~instr_list ~instr_table
      ~instr_ensemble_group_selection ~number_of_instrument_groups ~ed_list
      ~ed_table ~ent_ensemble_group_selection ~perf_list ~performance_table
      ~perf_ensemble_group_selection ~dyn_list ~dynamics_table
      ~dyn_ensemble_group_selection ~entrydelay_combination
      ~instrument_principle ~entrydelay_principle ~performance_principle
      ~performance_combination ~performance_mode ~dynamics_principle
      ~dynamics_combination ~dynamics_mode ~union ~density ~hierarchy ~dur_list
      ~dur_table ~duration_combination ~dur_ensemble_group_selection
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
    | Error e -> Error [ ParseError e ]
    | Ok sexps -> of_sexp sexps
end
