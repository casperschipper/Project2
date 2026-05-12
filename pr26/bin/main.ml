open Pr26.Basics
open Pr26.Tools

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

let groupspec =
  GroupSpec
    {
      element = GroupSeries;
      repetition = GroupSeries;
      min_rep = 1;
      max_rep = 5;
    }

let test_tendency_mask () =
  let labels =
    [ "parallel"; "widening"; "narrowing"; "crosswise" ] |> List.to_seq
  in
  print_endline "Testing a mask of 100 values, showing the sections by 25";
  test_mask |> tendency_mask_raw 100
  |> chunk (Seq.repeat 25)
  |> Seq.zip labels
  |> Seq.iter (fun (label, vals) ->
      print_float_list label (vals |> List.of_seq))

let test_estimating_entry_delay () =
  (* 0 1 2 3 4 5 6 7 8 9  10 11 12 13 14 15*)
  let entry_delay_array =
    [ 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14; 15; 16 ]
    |> List.map (fun x -> float_of_int x *. 0.1)
    |> mk_par_list mk_entrydelay |> Result.get_ok
  in
  let entry_delay_table =
    [
      [ 0; 1; 2; 3; 4; 5 ];
      [ 0; 1; 3 ];
      [ 0; 7; 15 ];
      [ 0; 1; 2; 6; 10; 12 ];
      [ 0; 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14; 15 ];
    ]
    |> of_nested_list
  in
  let entry_delay_ensemble =
    construct_ensemble entry_delay_array entry_delay_table EnsembleGroupAlea 2
  in
  let test_expected_value principle =
    print_string (principle_to_string principle);
    expected_value principle (ensemble_values_union entry_delay_ensemble)
    |> Printf.printf "\n%f";
    print_endline " \n"
  in
  let _ =
    print_endline "\n";
    print_string "\ntest expected value\n";
    [
      Alea;
      Series;
      Ratio [ (0, 1); (1, 3); (2, 4) ];
      Group groupspec;
      Tendency test_mask;
      Sequence [ 0; 3; 5 ];
    ]
    |> List.map test_expected_value
  in
  ()

let write_score filename layers =
  let oc = open_out filename in
  List.iteri
    (fun i events ->
      Printf.fprintf oc "# layer %d\n" i;
      List.iter
        (fun { time; instrument = Instrument { name; _ }; chordsize } ->
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
        (fun { time; instrument = Instrument { name; _ }; chordsize } ->
          Printf.printf "%-8.3f %-12s %d\n" time name chordsize)
        events)
    layers

let instrument_entry_test () =
  (* we use the result monad in the form of let*, so we can combine a bunch of parameters that may be picky about their input,
   without having to wire through all the Error cases *)
  let ( let* ) = Result.bind in
  let _ = print_header "starting instrument entry test" in
  let result =
    let* instr_list =
      mk_par_list id
        [
          inst "guitar" (chordsize 1 2);
          inst "piano" (chordsize 1 10);
          inst "basedrum" (chordsize 1 1);
          inst "marimba" (chordsize 1 4);
        ]
    in
    let* ed_list =
      mk_par_list mk_entrydelay [ 0.1; 0.2; 0.3; 1.0; 2.0; 3.0; 2.0; 5.0 ]
    in
    let instr_table =
      of_nested_list [ [ 0; 1; 2; 3 ]; [ 0; 1; 3 ]; [ 1; 3 ]; [ 0 ] ]
    in
    let ed_table =
      of_nested_list
        [ [ 0; 1; 2 ]; [ 3; 4; 5 ]; [ 0; 1; 2; 3; 4; 5; 6; 7 ]; [ 6; 7 ] ]
    in
    let* d = mk_autonomous ~tr:12 ~a:1 ~z:10 ~selection_principle:Series in
    mk_score_config ~variant_duration:60.0 ~instr_list ~instr_table
      ~number_of_instrument_groups:3 ~ed_list ~ed_table ~combination:Combination
      ~instrument_principle:(Tendency test_mask) ~entry_delay_principle:Series
      ~union:NoUnion ~density:d
    |> Result.map build_score
  in
  match result with
  | Error e ->
      Printf.printf "instrument_entry_test failed: %s\n" (display_problem e)
  | Ok layers ->
      print_layers layers;
      write_score "score.projekt2" layers;
      print_endline "Score written to score.projekt2"

let () =
  (* some seed *)
  let _ = Random.init 93 in
  let print_int_list = Pr26.Tools.print_int_list in
  print_header "isolated test of tendency masks";
  test_tendency_mask ();
  ratio_sq [ (0, 1); (1, 2); (3, 4) ]
  |> Seq.take 100 |> List.of_seq
  |> print_int_list "\n\n Selection Principle: ratio (1,1) (42,3) (3,10)";
  alea_sq [| 0; 1; 2; 3; 4; 5 |]
  |> Seq.take 30 |> List.of_seq
  |> print_int_list "\n\nalea 5";
  let ensemble = [ 0; 1; 2; 3; 4 ] in
  let take30 label sq =
    sq |> Seq.take 30 |> List.of_seq |> print_int_list label
  in
  group_sq ensemble (mkGroup GroupAlea GroupAlea 1 5)
  |> take30 "group_sq AleaElem  / AleaRep";
  group_sq ensemble (mkGroup GroupSeries GroupAlea 1 5)
  |> take30 "group_sq SeriesElem / AleaRep";
  group_sq ensemble (mkGroup GroupSeries GroupSeries 1 5)
  |> take30 "group_sq SeriesElem / SeriesRep";
  group_sq ensemble (mkGroup GroupAlea GroupSeries 1 5)
  |> take30 "group_sq AleaElem  / SeriesRep";
  series_sq 5 |> take30 "series";
  test_tendency_mask ();
  test_estimating_entry_delay ();
  instrument_entry_test ();
  ()
