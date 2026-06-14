open Parameters
open Selection
open Tools

type combination =
  | Combination
  (* index of combined parameters is the same as instrument parameter *)
  | NoCombination
(* 
- parameter selects their own group
- independent of instrument
- only one group is selected
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
