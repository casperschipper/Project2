open Pr26.Parameters
open Pr26.Structure_formula
open Pr26.Score_generation
open Pr26.Tools
open Pr26.Selection

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

let basic_test () =
  let _ = print_header "starting instrument entry test" in
  let pure = Validated.pure in
  let ( <+> ) = Validated.( <+> ) in
  (* applicative of result, but collect multiple errors in list *)
  let ( <$> ) = Validated.( <$> ) in
  (* just map over error *)
  let pitch_compass =
    mk_pitch_compass (absolute (Register 1) 1) (absolute (Register 5) 12)
      Pitch_set.empty
  in
  (* define some instrument modes *)
  let normal = Performance.of_string "normal" in
  let pluck = Performance.of_string "plucking" in
  let bow = Performance.of_string "bowing" in
  (* define instruments with these modes *)
  let guitar = mk_instr "guitar" in
  let piano = mk_instr "piano" in
  let basedrum = mk_instr "basedrum" in
  let marimba = mk_instr "marimba" in
  let limited_dynamics =
    [ "mf"; "f"; "ff"; "fff" ] |> List.map Dynamic.of_string
    |> Dynamic_modes.of_list
  in
  let instr_validated =
    (* add pitch compass, use error applicative to collect mistakes *)
    let of_list = Performance_modes.of_list in
    let durations = mk_allowed_durations 0.25 4.0 in
    Validated.sequence
      [
        inst <$> guitar <+> chordsize 1 2
        <+> pure (of_list [ normal; pluck; bow ])
        <+> pure default_dynamics <+> pitch_compass <+> durations;
        inst <$> piano <+> chordsize 1 10
        <+> pure (of_list [ normal; bow ])
        <+> pure default_dynamics <+> pitch_compass <+> durations;
        inst <$> basedrum <+> chordsize 1 1
        <+> pure (of_list [ pluck; bow ])
        <+> pure default_dynamics <+> pitch_compass <+> durations;
        inst <$> marimba <+> chordsize 1 4
        <+> pure (of_list [ normal ])
        <+> pure limited_dynamics <+> pitch_compass <+> durations;
      ]
  in
  match instr_validated with
  | Error errors -> print_errors "instrument_entry_test (instruments)" errors
  | Ok instrs -> (
      let instr_list = ParameterList (Array.of_list instrs) in
      let instr_table = of_nested_list [ [ 0; 1; 2; 3 ]; [ 0; 1 ]; [ 2; 3 ] ] in
      let ed_table =
        of_nested_list [ [ 0; 1; 2 ]; [ 3; 4; 5 ]; [ 0; 1; 2; 3; 4; 5; 6; 7 ] ]
      in
      let performance_table =
        of_nested_list [ [ 0; 1; 2 ]; [ 0; 2 ]; [ 1; 2 ] ]
      in
      (* default_dynamics sorted: f=0, ff=1, fff=2, mf=3, p=4, pp=5, ppp=6 *)
      let dynamics_table =
        of_nested_list
          [
            [ 0; 1; 2; 3; 4; 5; 6 ];
            [ 0; 1; 2; 3; 4; 5; 6 ];
            [ 0; 1; 2; 3; 4; 5; 6 ];
          ]
      in
      let dur_table = of_nested_list [ [ 0; 1; 2 ]; [ 3; 4 ]; [ 0; 1; 2; 3; 4 ] ] in
      let result =
        Validated.join_v
          ((fun ed_list dur_list d hier ->
             mk_structure_formula ~variant_duration:180.0 ~instr_list
               ~instr_table ~instr_ensemble_group_selection:EnsembleGroupSeries
               ~number_of_instrument_groups:3 ~ed_list ~ed_table
               ~ent_ensemble_group_selection:EnsembleGroupSeries
               ~performance_table
               ~perf_ensemble_group_selection:EnsembleGroupSeries
               ~dynamics_table ~dyn_ensemble_group_selection:EnsembleGroupSeries
               ~entrydelay_combination:NoCombination ~instrument_principle:Alea
               ~entrydelay_principle:Series ~performance_principle:Alea
               ~performance_combination:Combination
               ~dynamics_principle:(Tendency test_mask)
               ~dynamics_combination:Combination ~union:NoUnion ~density:d
               ~hierarchy:hier ~dur_list ~dur_table
               ~duration_combination:NoCombination
               ~dur_ensemble_group_selection:EnsembleGroupSeries
               ~duration_relation_mode:(DurIndependent ChordOneDuration)
             |> Result.map build_score)
          <$> mk_par_list mk_entrydelay
                [ 0.1; 0.2; 0.3; 1.0; 2.0; 3.0; 2.0; 5.0 ]
          <+> mk_par_list mk_duration [ 0.25; 0.5; 1.0; 2.0; 4.0 ]
          <+> mk_autonomous ~tr:12 ~low:1 ~high:3 ~selection_principle:Series
          <+> mk_hierarchy [ Dyn; Ins; Per ])
      in
      match result with
      | Error errors -> print_errors "instrument_entry_test" errors
      | Ok layers ->
          print_layers instrs layers;
          write_score "score.projekt2" instrs layers;
          print_endline "Score written to score.projekt2")

let () =
  (* some seed *)
  ignore (Random.init 2);
  basic_test ()
