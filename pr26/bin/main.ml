open Pr26.Basics
open Pr26.Tools
open Pr26.Selection

let uf = UnitFloat.of_float_exn

let mk portion smin smax emin emax =
  TendencySection
    {
      portion;
      start_min = uf smin;
      start_max = uf smax;
      end_min = uf emin;
      end_max = uf emax;
    }

let test_mask =
  TendencyMask
    [
      mk 1.0 0.2 0.3 0.8 0.9;
      (* parallel  : window stays fixed           *)
      mk 1.0 0.0 0.1 0.1 1.0;
      (* widening  : window expands outward        *)
      mk 1.0 0.0 1.0 0.0 0.1;
      (* narrowing : window shrinks inward         *)
      mk 1.0 0.2 0.8 0.8 0.2;
      (* crosswise : boundaries cross at midpoint  *)
    ]

let write_score filename layers =
  let oc = open_out filename in
  List.iteri
    (fun i events ->
      Printf.fprintf oc "# layer %d\n" i;
      List.iter
        (fun { time; instrument = InstrumentName name; chordsize } ->
          Printf.fprintf oc "%.3f %s %d\n" time name chordsize)
        events)
    layers;
  close_out oc

let print_layers layers =
  print_endline "\n=== instrument_entry_test ===";
  List.iteri
    (fun i events ->
      Printf.printf "\n--- layer %d ---\n" i;
      Printf.printf "%-8s %-12s %s\n" "time" "instrument" "chordsize";
      List.iter
        (fun { time; instrument = InstrumentName name; chordsize } ->
          Printf.printf "%-8.3f %-12s %d\n" time name chordsize)
        events)
    layers

let print_errors label errors =
  Printf.printf "%s failed:\n" label;
  List.iter (fun e -> Printf.printf "  - %s\n" (display_problem e)) errors

let instrument_entry_test () =
  let _ = print_header "starting instrument entry test" in
  let pure = Validated.pure in
  let ( <+> ) = Validated.( <+> ) in
  (* applicative of result, but collect multiple errors in list *)
  let ( <$> ) = Validated.( <$> ) in
  (* just map over error *)
  let pitch_compass =
    mk_pitch_compass (absolute 1 1) (absolute 5 12) Pitch_set.empty
  in
  let performance_modes =
    Performance_modes.of_list [ Performance.of_string "normal" ]
  in
  let guitar = mk_instr "guitar" in
  let piano = mk_instr "piano" in
  let basedrum = mk_instr "basedrum" in
  let marimba = mk_instr "marimba" in
  let instr_validated =
    Validated.sequence
      [
        inst <$> guitar <+> chordsize 1 2 <+> pure performance_modes
        <+> pitch_compass;
        inst <$> piano <+> chordsize 1 10 <+> pure performance_modes
        <+> pitch_compass;
        inst <$> basedrum <+> chordsize 1 1 <+> pure performance_modes
        <+> pitch_compass;
        inst <$> marimba <+> chordsize 1 4 <+> pure performance_modes
        <+> pitch_compass;
      ]
  in
  match instr_validated with
  | Error errors -> print_errors "instrument_entry_test (instruments)" errors
  | Ok instrs -> (
      let ( <$> ) = Validated.( <$> ) in
      let ( <+> ) = Validated.( <+> ) in
      let instr_list = ParameterList (Array.of_list instrs) in
      let instr_table = of_nested_list [ [ 0; 1; 2; 3 ]; [ 1; 3 ]; [ 0 ] ] in
      let ed_table =
        of_nested_list
          [ [ 0; 1; 2 ]; [ 3; 4; 5 ]; [ 0; 1; 2; 3; 4; 5; 6; 7 ]; [ 6; 7 ] ]
      in
      let result =
        Validated.join
          ((fun ed_list d hier ->
             mk_structure_formula ~variant_duration:60.0 ~instr_list
               ~instr_table ~number_of_instrument_groups:3 ~ed_list ~ed_table
               ~entrydelay_combination:Combination
               ~instrument_principle:(Tendency test_mask)
               ~entrydelay_principle:Series ~union:NoUnion ~density:d
               ~hierarchy:hier
             |> Result.map build_score)
          <$> mk_par_list mk_entrydelay
                [ 0.1; 0.2; 0.3; 1.0; 2.0; 3.0; 2.0; 5.0 ]
          <+> mk_autonomous ~tr:12 ~low:1 ~high:10
                ~selection_principle:(Tendency test_mask)
          <+> mk_hierarchy [ Ins; Ent ])
      in
      match Validated.join_v result with
      | Error errors -> print_errors "instrument_entry_test" errors
      | Ok layers ->
          print_layers layers;
          write_score "score.projekt2" layers;
          print_endline "Score written to score.projekt2")

let () =
  (* some seed *)
  ignore (Random.init 93);
  instrument_entry_test ()
