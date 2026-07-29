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

(* Shared fixture for the Stage 1/Stage 2 continuity regressions below: one
   instrument, "union none" with 2 instrument groups (=> 2 layers per
   variant), and an uncombined entry-delay parameter whose 9-element list is
   deliberately partitioned into three *disjoint* 3-element table rows. With
   "ensemble series" (a cycle that cannot repeat a row until all three have
   been used), any three consecutive layers - whether they span only layers
   within one variant, or a variant boundary too - are *guaranteed* to draw
   all three distinct rows, whatever the seed: 9 distinct entry-delay values
   in total. A bug that broadcasts/restarts instead of continuing the cycle
   would confine some of those layers to a repeated row, giving fewer than 9
   distinct values overall - regardless of seed, since a repeat can only
   happen if the cycle failed to continue. *)
let test_formula_sexp ~n_variants =
  Printf.sprintf
    {|(structure-formula
  (seed 7)
  (variant-duration 20.0)
  (n-variants %d)
  (octave-division 12)

  (dynamics (mf))
  (dynamics-table (0))

  (performance (normal))
  (performance-table (0))

  (number-of-instrument-groups 2)
  (instruments
    (instrument only
      (chordsize 1 1)
      (performance (normal))
      (dynamics (mf))
      (pitch-range percussion)
      (durations 0.1 1.0)))
  (instrument-table (0) (0))

  (entrydelays (0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9))
  (entrydelay-table (0 1 2) (3 4 5) (6 7 8))

  (durations (0.2))
  (duration-table (0))

  (registers ((pitch-range percussion)))
  (register-table (0))

  (harmony
    (row (p))
    (transposition none))

  (principles
    (instrument (ensemble series) (order series))
    (entrydelay (ensemble series) (order series))
    (performance (ensemble series) (order series) (mode per-chord))
    (dynamics (ensemble series) (order series) (mode per-chord))
    (duration (ensemble series) (order series) (relation (independent per-chord)))
    (register (ensemble series) (order series) (mode per-chord)))

  (hierarchy (Ins Reg Har Per Dyn Ent Dur))
  (union none)
  (density instrument-density)
)|}
    n_variants

let build_test_formula ~n_variants =
  let open Pr26.Structure_formula in
  match Pr26.Sexp.of_string (test_formula_sexp ~n_variants) with
  | Error e -> failwith ("test formula failed to parse: " ^ e)
  | Ok sexps -> (
      match Parse.of_sexp sexps with
      | Error (errors, _) ->
          failwith
            (Printf.sprintf "test formula failed to build: %d error(s)"
               (List.length errors))
      | Ok (sf, _warnings) -> sf)

let entrydelays_of layer =
  layer |> List.map (fun (e : Pr26.Score_generation.entry) -> e.entrydelay)

(* Stage 1 regression (EMR-3 p.130-132): an uncombined parameter's group
   selection draws a fresh group *every layer*, continuing one selection
   cycle across the whole run - it must not broadcast a single group to
   every layer, as the old code did. Exercised end to end through the real
   parser and [build_score], not just the isolated helper, since the bug was
   in how [build_score] requested groups from [construct_ensemble] as much as
   in how state was threaded between layers. *)
let () =
  let sf = build_test_formula ~n_variants:1 in
  let variants = Pr26.Score_generation.build_score sf in
  assert (List.length variants = 1);
  let layers = List.hd variants in
  assert (List.length layers = 2);
  let distinct =
    List.nth layers 0 |> entrydelays_of
    |> ( @ ) (List.nth layers 1 |> entrydelays_of)
    |> List.sort_uniq compare
  in
  assert (List.length distinct > 3);
  print_endline "cross-layer group-selection continuity: test passed"

(* Stage 2 regression: the same continuing selection cycle spans a variant
   boundary too, not just a layer boundary within one variant - it resets
   only with a new variant *group* (EMR-3 9.8: "in the variant group each
   new variant simply continues..."). 2 variants x 2 layers = 4 total group
   draws from the same 3-row cycle; the first 3 of those (variant 0's two
   layers, then variant 1's first) must be all 3 distinct rows. *)
let () =
  let sf = build_test_formula ~n_variants:2 in
  let variants = Pr26.Score_generation.build_score sf in
  assert (List.length variants = 2);
  List.iter (fun layers -> assert (List.length layers = 2)) variants;
  let variant0 = List.nth variants 0 in
  let variant1 = List.nth variants 1 in
  let first_three_layers =
    [ List.nth variant0 0; List.nth variant0 1; List.nth variant1 0 ]
  in
  let distinct =
    first_three_layers |> List.concat_map entrydelays_of
    |> List.sort_uniq compare
  in
  assert (List.length distinct = 9);
  print_endline "cross-variant group-selection continuity: test passed"
