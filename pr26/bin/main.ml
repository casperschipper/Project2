let print_int_list label lst =
  Printf.printf "%s:\n [%s]\n" label
    (lst |> List.map string_of_int |> String.concat "; ")


open Pr26.Basics

let () =
  let _ = Random.init 5 in
  print_string "lets run some simple tests\n";
  ratio_sq [(1,1);(42,3);(3,10)] |> Seq.take 100 |> List.of_seq |> print_int_list "ratio (1,1) (42,3) (3,10)";
  alea_sq [|0;1;2;3;4;5|] |> Seq.take 30 |> List.of_seq |> print_int_list "alea 5";
  let ensemble = [0;1;2;3;4] in
  let take30 label sq = sq |> Seq.take 30 |> List.of_seq |> print_int_list label in
  group_sq ensemble (mkGroup GroupAlea   GroupAlea   1 5) |> take30 "group_sq AleaElem  / AleaRep";
  group_sq ensemble (mkGroup GroupSeries GroupAlea   1 5) |> take30 "group_sq SeriesElem / AleaRep";
  group_sq ensemble (mkGroup GroupSeries GroupSeries 1 5) |> take30 "group_sq SeriesElem / SeriesRep";
  group_sq ensemble (mkGroup GroupAlea   GroupSeries 1 5) |> take30 "group_sq AleaElem  / SeriesRep"
