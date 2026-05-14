let () =
  assert (Pr26.Tools.sequence_result [] = Ok []);
  assert (Pr26.Tools.sequence_result [Ok 1; Ok 2] = Ok [1; 2]);
  assert (Pr26.Tools.sequence_result [Ok 1; Error "bad"; Ok 3] = Error "bad");
  assert (Pr26.Tools.sequence_result [Error "first"; Error "second"] = Error "first");
  print_endline "sequence_result: all tests passed"

let () =
  let arr = [| 1; 2; 3; 4; 5 |] in
  let init = Pr26.Selection.series_init arr in
  Pr26.Selection.to_seq Pr26.Selection.series_draw init
  |> Seq.take 20
  |> Seq.map Pr26.Selection.get_value
  |> Seq.iter (Printf.printf "%d ");
  print_endline "series to_seq: done"

let () =
  let init = Pr26.Selection.alea_init [| 1; 2; 3; 4; 5 |] in
  Pr26.Selection.to_seq Pr26.Selection.alea_draw init
  |> Seq.take 10
  |> Seq.map Pr26.Selection.get_value
  |> Seq.iter (Printf.printf "%d ");
  print_endline "alea to_seq: done"

let () =
  let init = Pr26.Selection.ratio_init [ (1, 2); (2, 10); (3, 1) ] in
  Pr26.Selection.to_seq Pr26.Selection.ratio_draw init
  |> Seq.take 10
  |> Seq.map Pr26.Selection.get_value
  |> Seq.iter (Printf.printf "%d ");
  print_endline "ratio to_seq: done"

let () =
  (* 3 values, take 9 = 3 loops — should see 1 2 3 repeated exactly *)
  let init = Pr26.Selection.sequence_init [ 11;12;13 ] in
  let results =
    Pr26.Selection.to_seq Pr26.Selection.sequence_draw init
    |> Seq.take 9
    |> Seq.map Pr26.Selection.get_value
    |> List.of_seq
  in
  assert (results = [ 11;12;13;11;12;13;11;12;13 ]);
  List.iter (Printf.printf "%d ") results;
  print_endline "sequence to_seq: done"

let () =
  let spec =
    Pr26.Selection.GroupSpec
      { element = Pr26.Selection.GroupSeries; repetition = Pr26.Selection.GroupAlea;
        min_rep = 2; max_rep = 4 }
  in
  let init = Pr26.Selection.group_init [| "x"; "y"; "z" |] spec in
  Pr26.Selection.to_seq Pr26.Selection.group_draw init
  |> Seq.take 20
  |> Seq.map Pr26.Selection.get_value
  |> Seq.iter print_endline;
  print_endline "group to_seq: done"
