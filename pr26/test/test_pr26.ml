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
  |> Seq.take 20
  |> Seq.map Pr26.Selection.get_value
  |> Seq.iter (Printf.printf "%d ");
  print_endline "alea to_seq: done"

let () =
  let init = Pr26.Selection.ratio_init [ (1, 2); (2, 10); (3, 1) ] in
  Pr26.Selection.to_seq Pr26.Selection.ratio_draw init
  |> Seq.take 20
  |> Seq.map Pr26.Selection.get_value
  |> Seq.iter (Printf.printf "%d ");
  print_endline "ratio to_seq: done"

let () =
  (* 3 values, take 9 = 3 loops — should see 1 2 3 repeated exactly *)
  let init = Pr26.Selection.sequence_init [ 11;12;13 ] in
  let results =
    Pr26.Selection.to_seq Pr26.Selection.sequence_draw init
    |> Seq.take 18
    |> Seq.map Pr26.Selection.get_value
    |> List.of_seq
  in
  assert (results = [ 11;12;13;11;12;13;11;12;13;11;12;13;11;12;13;11;12;13 ]);
  List.iter (Printf.printf "%d ") results;
  print_endline "sequence to_seq: done"

let () =
  let spec =
    Pr26.Selection.GroupSpec
      { element = Pr26.Selection.GroupSeries; repetition = Pr26.Selection.GroupSeries;
        min_rep = 1; max_rep = 3 }
  in
  let init = Pr26.Selection.group_init [| 1;2;3 |] spec in
  Pr26.Selection.to_seq Pr26.Selection.group_draw init
  |> Seq.take 20
  |> Seq.map Pr26.Selection.get_value
  |> Seq.iter (fun i -> Printf.printf "%d " i);
  print_endline "group to_seq: done"

(* [resolve_pitch] combines REGISTER + HARMONY's row value into a final
   pitch (or [Percussion], as a real value rather than PR-2's (0,0)/0
   sentinel). *)
let () =
  let open Pr26.Parameters in
  let ap o s = absolute (Octave o) (Step s) in
  (* EMR-3 §7.1's own worked example: register (401,512), relative pitch 5,
     can occupy 405 or 505 - the lowest match (405) is taken. *)
  let reg_4_5 = Result.get_ok (mk_register (ap 4 1) (ap 5 12)) in
  assert (resolve_pitch reg_4_5 (Tone (Step 5)) = (Pitched (ap 4 5), true));
  (* register (401,504): relative pitch 5 can only occupy 405. *)
  let reg_4_4 = Result.get_ok (mk_register (ap 4 1) (ap 4 4)) in
  assert (resolve_pitch reg_4_4 (Tone (Step 5)) = (Pitched (ap 4 1), false));
  (* percussion register/row value agree -> a real [Percussion], never a
     (0,0)/0 sentinel. *)
  assert (resolve_pitch PercussionRegister RowPercussion = (Percussion, true));
  (* mismatches: flagged not-ok rather than silently accepted. *)
  assert (resolve_pitch PercussionRegister (Tone (Step 3)) = (Percussion, false));
  assert (resolve_pitch reg_4_5 RowPercussion = (Pitched (ap 4 1), false));
  print_endline "resolve_pitch: all tests passed"

(* [register_compatible_with_pitch_range] mirrors instrument/register
   conditioning (EMR-3 fig 7-6): percussion only pairs with percussion,
   pitched only with an overlapping range. *)
let () =
  let open Pr26.Parameters in
  let ap o s = absolute (Octave o) (Step s) in
  let pitch_range = Result.get_ok (mk_pitch_range (ap 3 1) (ap 5 12) Pitch_set.empty) in
  let reg_overlap = Result.get_ok (mk_register (ap 4 1) (ap 6 12)) in
  let reg_no_overlap = Result.get_ok (mk_register (ap 6 1) (ap 7 12)) in
  assert (register_compatible_with_pitch_range pitch_range reg_overlap);
  assert (not (register_compatible_with_pitch_range pitch_range reg_no_overlap));
  assert (register_compatible_with_pitch_range PercussionPitchRange PercussionRegister);
  assert (not (register_compatible_with_pitch_range PercussionPitchRange reg_overlap));
  assert (not (register_compatible_with_pitch_range pitch_range PercussionRegister));
  print_endline "register_compatible_with_pitch_range: all tests passed"
