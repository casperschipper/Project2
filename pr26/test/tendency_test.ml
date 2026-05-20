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
      mk 1.0 0.0 0.1 0.1 1.0;
      mk 1.0 0.0 1.0 0.0 0.1;
      mk 1.0 0.2 0.8 0.8 0.2;
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
  print_endline "\ntest expected value";
  List.iter test_expected_value
    [
      Alea;
      Series;
      Ratio [ (0, 1); (1, 3); (2, 4) ];
      Group groupspec;
      Tendency test_mask;
      Sequence [ 0; 3; 5 ];
    ]

let () =
  Random.init 93;
  test_tendency_mask ();
  test_estimating_entry_delay ()
