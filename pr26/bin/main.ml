open Pr26.Basics
open Pr26.Tools

(* convenience: we know these literals are valid, so unwrap directly *)
let uf x = UnitFloat.make x |> Option.get

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
  test_mask |> tendency_mask_raw 100 |> List.of_seq
  |> print_float_list
       "tendency_mask (parallel / widening / narrowing / crosswise)"

let _end_to_end () =
  (* define instruments *)
  let violin = inst "violin" (chordsize 1 2) in

  let piano = inst "piano" (chordsize 1 10) in

  let basedrum = inst "basedrum" (chordsize 1 1) in

  (* note: the list from list-table-ensemble in PR2 is actually array
  , as we want to index them using ints *)
  let _instruments_array = [| violin; piano; basedrum |] in

  let _instr_table =
    of_nested_list [ [ 0; 1; 2 ]; [ 0; 1 ]; [ 0; 3 ]; [ 0 ] ]
  in
  (* 0 1 2 3 4 5 6 7 8 9  10 11 12 13 14 15*)
  let entry_delay_array =
    [ 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14; 15; 16 ]
    |> List.map (fun x -> float_of_int x *. 0.1)
    |> mk_par_list mk_entrydelay
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
    expected_value principle entry_delay_ensemble |> Printf.printf "\n%f";
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

let () =
  let _ = Random.init 5 in
  let print_int_list = Pr26.Tools.print_int_list in
  print_string "lets run some simple tests\n";
  test_tendency_mask ();
  ratio_sq [ (0, 1); (1, 2); (3, 4) ]
  |> Seq.take 100 |> List.of_seq
  |> print_int_list "ratio (1,1) (42,3) (3,10)";
  alea_sq [| 0; 1; 2; 3; 4; 5 |]
  |> Seq.take 30 |> List.of_seq |> print_int_list "alea 5";
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
  test_tendency_mask ();
  _end_to_end ();
  ()
