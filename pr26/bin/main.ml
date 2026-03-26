let print_int_list label lst =
  Printf.printf "%s:\n [%s]\n" label
    (lst |> List.map string_of_int |> String.concat "; ")


open Pr26.Basics

let print_float_list label lst =
  Printf.printf "%s:\n [%s]\n" label
    (lst |> List.map (Printf.sprintf "%.3f") |> String.concat "; ")

(* convenience: we know these literals are valid, so unwrap directly *)
let uf x = UnitFloat.make x |> Option.get

let mk weight smin smax emin emax =
  TendencySection { weight; start_min = uf smin; start_max = uf smax;
                             end_min   = uf emin; end_max   = uf emax }

let test_tendency_mask () =
  let sections = [
    mk 1.0  0.2 0.3  0.8 0.9;   (* parallel  : window stays fixed           *)
    mk 1.0  0.0 0.1  0.1 1.0;   (* widening  : window expands outward        *)
    mk 1.0  0.0 1.0  0.0 0.1;   (* narrowing : window shrinks inward         *)
    mk 1.0  0.2 0.8  0.8 0.2;   (* crosswise : boundaries cross at midpoint  *)
  ] in
  tendency_mask 100 sections
  |> List.of_seq
  |> print_float_list "tendency_mask (parallel / widening / narrowing / crosswise)"

let () =
  let _ = Random.init 5 in
  print_string "lets run some simple tests\n";
  test_tendency_mask ();
  ratio_sq [(1,1);(42,3);(3,10)] |> Seq.take 100 |> List.of_seq |> print_int_list "ratio (1,1) (42,3) (3,10)";
  alea_sq [|0;1;2;3;4;5|] |> Seq.take 30 |> List.of_seq |> print_int_list "alea 5";
  let ensemble = [0;1;2;3;4] in
  let take30 label sq = sq |> Seq.take 30 |> List.of_seq |> print_int_list label in
  group_sq ensemble (mkGroup GroupAlea   GroupAlea   1 5) |> take30 "group_sq AleaElem  / AleaRep";
  group_sq ensemble (mkGroup GroupSeries GroupAlea   1 5) |> take30 "group_sq SeriesElem / AleaRep";
  group_sq ensemble (mkGroup GroupSeries GroupSeries 1 5) |> take30 "group_sq SeriesElem / SeriesRep";
  group_sq ensemble (mkGroup GroupAlea   GroupSeries 1 5) |> take30 "group_sq AleaElem  / SeriesRep";
  test_tendency_mask ()