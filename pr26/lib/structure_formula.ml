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
  dynamics_table : ptable;
  instrument_principle : selection_principle;
  entrydelay_principle : selection_principle;
  entrydelay_combination : combination;
  performance_principle : selection_principle;
  performance_combination : combination;
  dynamics_principle : selection_principle;
  dynamics_combination : combination;
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

let mk_structure_formula ~variant_duration ~instr_list ~instr_table ~ed_list
    ~ed_table ~number_of_instrument_groups ~performance_table ~dynamics_table
    ~entrydelay_combination ~instrument_principle ~entrydelay_principle
    ~performance_principle ~performance_combination ~dynamics_principle
    ~dynamics_combination ~union ~hierarchy ~density =
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
          dynamics_table;
          entrydelay_combination;
          instrument_principle;
          entrydelay_principle;
          performance_principle;
          performance_combination;
          dynamics_principle;
          dynamics_combination;
          union;
          density;
          hierarchy;
        }
  | errs -> Error errs

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

  (* performance-table / dynamics-table entries may either be raw indexes into
     the mode list derived from the instruments (kept for backwards
     compatibility), or the mode names themselves, resolved against [names]
     (given in the same order as [extract_performances_from_instruments] /
     [extract_dynamics_from_instruments]) *)
  let parse_named_table unknown names items =
    let index_of_name = names |> List.mapi (fun i name -> (name, i)) in
    let resolve_cell = function
      | Sexp.Atom s -> (
          match int_of_string_opt s with
          | Some i -> Ok i
          | None -> (
              match List.assoc_opt s index_of_name with
              | Some i -> Ok i
              | None -> lift (Error (unknown s))))
      | Sexp.List _ -> fail "expected atom for table entry"
    in
    let parse_row = function
      | Sexp.List row_items ->
          let* ints = row_items |> List.map resolve_cell |> sequence in
          Ok (Array.of_list ints)
      | Sexp.Atom _ -> fail "expected list for table row, got atom"
    in
    let* rows = items |> List.map parse_row |> sequence in
    Ok (Table (Array.of_list rows))

  let parse_combination = function
    | [ Sexp.Atom "none" ] -> Ok NoCombination
    | [ Sexp.Atom "combination" ] -> Ok Combination
    | _ -> fail "expected 'none' or 'combination'"

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

  let parse_principle items =
    match items with
    | [ Sexp.Atom "alea" ] -> Ok Alea
    | [ Sexp.Atom "series" ] -> Ok Series
    | [ Sexp.List (Sexp.Atom "sequence" :: [ Sexp.List ints ]) ] ->
        let* is = ints |> List.map require_int |> sequence in
        Ok (Sequence is)
    | [ Sexp.List (Sexp.Atom "ratio" :: pairs) ] ->
        let parse_pair = function
          | Sexp.List [ Sexp.Atom a; Sexp.Atom b ] ->
              let* i = require_int (Sexp.Atom a) in
              let* w = require_int (Sexp.Atom b) in
              Ok (i, w)
          | _ -> fail "ratio pair expects (index weight)"
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
          (mk_pitch_compass (absolute r1 p1) (absolute r2 p2) Pitch_set.empty)
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
        Ok (inst instr cs perf dyns compass)
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
        let* tr_v = get_int "tr" in
        let* p =
          let* a = require_field "principle" args in
          parse_principle a
        in
        lift
          (mk_autonomous ~tr:tr_v ~low:low_v ~high:high_v ~selection_principle:p)
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
    let (ParameterList instr_arr) = instr_list in
    let* performance_table =
      let* args = require_field "performance-table" items in
      let (ParameterList perf_arr) =
        extract_performances_from_instruments (Array.to_list instr_arr)
      in
      let perf_names =
        perf_arr |> Array.to_list |> List.map Performance.to_string
      in
      parse_named_table (fun s -> UnknownPerformance s) perf_names args
    in
    let* dynamics_table =
      let* args = require_field "dynamics-table" items in
      let (ParameterList dyn_arr) =
        extract_dynamics_from_instruments (Array.to_list instr_arr)
      in
      let dyn_names = dyn_arr |> Array.to_list |> List.map Dynamic.to_string in
      parse_named_table (fun s -> UnknownDynamic s) dyn_names args
    in
    let* principles = require_field "principles" items in
    let* instrument_principle =
      let* args = require_field "instrument" principles in
      parse_principle args
    in
    let* entrydelay_principle =
      let* args = require_field "entrydelay" principles in
      parse_principle args
    in
    let* performance_principle =
      let* args = require_field "performance" principles in
      parse_principle args
    in
    let* dynamics_principle =
      let* args = require_field "dynamics" principles in
      parse_principle args
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
    mk_structure_formula ~variant_duration ~instr_list ~instr_table
      ~number_of_instrument_groups ~ed_list ~ed_table ~performance_table
      ~dynamics_table ~entrydelay_combination ~instrument_principle
      ~entrydelay_principle ~performance_principle ~performance_combination
      ~dynamics_principle ~dynamics_combination ~union ~density ~hierarchy

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
