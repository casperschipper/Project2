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
        (fun { time; instrument = InstrumentName name; chordsize; _ } ->
          Printf.fprintf oc "%.3f %s %d\n" time name chordsize)
        events)
    layers;
  close_out oc

let print_layers layers =
  print_endline "\n=== instrument_entry_test ===";
  List.iteri
    (fun i events ->
      Printf.printf "\n--- layer %d ---\n" i;
      Printf.printf "%-8s %-14s %-5s %s\n" "time" "instrument" "cs"
        "performance";
      List.iter
        (fun { time; instrument = InstrumentName name; chordsize; performance }
           ->
          Printf.printf "%-8.3f %-14s %-5d %s\n" time name chordsize
            (Performance.to_string performance))
        events)
    layers

let verify_hierarchy instrs layers =
  let perf_map =
    List.map
      (fun (Instrument { instrument; performance; _ }) ->
        (instrument, performance))
      instrs
  in
  let violations =
    List.concat_map
      (fun layer ->
        List.filter_map
          (fun event ->
            match List.assoc_opt event.instrument perf_map with
            | None -> Some "unknown instrument"
            | Some valid ->
                if Performance_modes.mem event.performance valid then None
                else
                  let valid_str =
                    Performance_modes.elements valid
                    |> List.map Performance.to_string
                    |> String.concat ", "
                  in
                  Some
                    (Printf.sprintf "%s got '%s' (valid: %s)"
                       (match event.instrument with InstrumentName n -> n)
                       (Performance.to_string event.performance)
                       valid_str))
          layer)
      layers
  in
  print_endline "\n=== Hierarchy verification ===";
  match violations with
  | [] -> print_endline "OK: every performance is valid for its instrument"
  | vs ->
      Printf.printf "VIOLATIONS (%d):\n" (List.length vs);
      List.iter (fun msg -> Printf.printf "  - %s\n" msg) vs

let print_errors label errors =
  Printf.printf "%s failed:\n" label;
  List.iter (fun e -> Printf.printf "  - %s\n" (display_problem e)) errors

let basic_test () =
  let _ = print_header "starting instrument entry test" in
  let pure = Validated.pure in
  let ( <+> ) = Validated.( <+> ) in
  (* applicative of result, but collect multiple errors in list *)
  let ( <$> ) = Validated.( <$> ) in
  (* just map over error *)
  let pitch_compass =
    mk_pitch_compass (absolute 1 1) (absolute 5 12) Pitch_set.empty
  in
  let normal = Performance.of_string "normal" in
  let pluck = Performance.of_string "plucking" in
  let bow = Performance.of_string "bowing" in
  let guitar = mk_instr "guitar" in
  let piano = mk_instr "piano" in
  let basedrum = mk_instr "basedrum" in
  let marimba = mk_instr "marimba" in
  let instr_validated =
    let of_list = Performance_modes.of_list in
    Validated.sequence
      [
        inst <$> guitar <+> chordsize 1 2
        <+> pure (of_list [ normal; pluck; bow ])
        <+> pitch_compass;
        inst <$> piano <+> chordsize 1 10
        <+> pure (of_list [ normal ])
        <+> pitch_compass;
        inst <$> basedrum <+> chordsize 1 1
        <+> pure (of_list [ pluck; bow ])
        <+> pitch_compass;
        inst <$> marimba <+> chordsize 1 4
        <+> pure (of_list [ normal ])
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
        of_nested_list [ [ 0; 1; 2 ]; [ 3; 4; 5 ]; [ 0; 1; 2; 3; 4; 5; 6; 7 ] ]
      in
      let performance_table =
        of_nested_list [ [ 0; 1; 2 ]; [ 1; 2 ]; [ 0; 2 ] ]
      in
      let result =
        Validated.join_v
          ((fun ed_list d hier ->
             mk_structure_formula ~variant_duration:60.0 ~instr_list
               ~instr_table ~number_of_instrument_groups:3 ~ed_list ~ed_table
               ~performance_table ~entrydelay_combination:NoCombination
               ~instrument_principle:Alea ~entrydelay_principle:Series
               ~performance_principle:(Tendency test_mask)
               ~performance_combination:Combination ~union:NoUnion ~density:d
               ~hierarchy:hier
             |> Result.map build_score)
          <$> mk_par_list mk_entrydelay
                [ 0.1; 0.2; 0.3; 1.0; 2.0; 3.0; 2.0; 5.0 ]
          <+> mk_autonomous ~tr:12 ~low:1 ~high:3 ~selection_principle:Alea
          <+> mk_hierarchy [ Per; Ins ])
      in
      match result with
      | Error errors -> print_errors "instrument_entry_test" errors
      | Ok layers ->
          print_layers layers;
          verify_hierarchy instrs layers;
          write_score "score.projekt2" layers;
          print_endline "Score written to score.projekt2")

let () =
  (* some seed *)
  ignore (Random.init 93);
  basic_test ()
