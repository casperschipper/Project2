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

(* [matrix_of_chord] (EMR-3 8.2 CHORD-INT, example 8-6): the chord is walked
   as a cyclic sequence of tones in both directions; consecutive intervals
   along each direction become allowed transitions. Verified against the
   manual's own (badly OCR'd, but decodable) worked example and an
   independently supplied one that confirms the same algorithm generalizes
   beyond 3-tone chords. *)
let () =
  let open Pr26.Parameters in
  let steps_of lst =
    lst |> List.map (fun n -> Result.get_ok (mk_step ~tr:12 n)) |> Array.of_list
  in
  let assert_matrix ~tr (IntervalMatrix m) allowed =
    for i = 1 to tr - 1 do
      for j = 1 to tr - 1 do
        let expected = List.mem (i, j) allowed in
        if m.(i - 1).(j - 1) <> expected then
          failwith
            (Printf.sprintf "matrix[%d][%d] = %b, expected %b" i j
               m.(i - 1).(j - 1) expected)
      done
    done
  in
  (* manual's own example 8-6: chord 5 6 10, tr=12 *)
  let m1 = Result.get_ok (matrix_of_chord ~tr:12 (steps_of [ 5; 6; 10 ])) in
  assert_matrix ~tr:12 m1 [ (1, 4); (4, 7); (7, 1); (5, 8); (8, 11); (11, 5) ];
  (* independently supplied example: chord 1 3 7, tr=12 *)
  let m2 = Result.get_ok (matrix_of_chord ~tr:12 (steps_of [ 1; 3; 7 ])) in
  assert_matrix ~tr:12 m2
    [ (2, 4); (4, 6); (6, 2); (6, 8); (8, 10); (10, 6) ];
  (match matrix_of_chord ~tr:12 (steps_of [ 5; 5; 6 ]) with
  | Error (IntervalChordHasRepeatedAdjacentTone 5) -> ()
  | _ -> failwith "expected IntervalChordHasRepeatedAdjacentTone");
  print_endline "matrix_of_chord: all tests passed"

(* [mk_interval_matrix_from_adjacency]: the sparse authoring form - rows
   never mentioned as a "given" interval stay entirely forbidden, and
   out-of-range/duplicate entries are rejected. *)
let () =
  let open Pr26.Parameters in
  let (IntervalMatrix m) =
    Result.get_ok
      (mk_interval_matrix_from_adjacency ~tr:5 [ (1, [ 1; 2 ]); (2, [ 1 ]) ])
  in
  assert (m.(0) = [| true; true; false; false |]);
  assert (m.(1) = [| true; false; false; false |]);
  assert (m.(2) = [| false; false; false; false |]);
  assert (m.(3) = [| false; false; false; false |]);
  (match mk_interval_matrix_from_adjacency ~tr:5 [ (1, [ 9 ]) ] with
  | Error (InvalidIntervalNumber { n = 9; tr = 5 }) -> ()
  | _ -> failwith "expected InvalidIntervalNumber");
  (match mk_interval_matrix_from_adjacency ~tr:5 [ (1, [ 1 ]); (1, [ 2 ]) ] with
  | Error (DuplicateIntervalMatrixEntry 1) -> ()
  | _ -> failwith "expected DuplicateIntervalMatrixEntry");
  print_endline "mk_interval_matrix_from_adjacency: all tests passed"

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
    (principle row)
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

(* ---- HARMONY's INTERVAL principle (EMR-3 8.2, entries 21-24) ---- *)

let build_interval_formula ~tr ~chordsize ~matrix_sexp ~forbidden_sexp
    ~density_sexp =
  let src =
    Printf.sprintf
      {|(structure-formula
  (seed 3)
  (variant-duration 5.0)
  (octave-division %d)

  (dynamics (mf))
  (dynamics-table (0))

  (performance (normal))
  (performance-table (0))

  (number-of-instrument-groups 1)
  (instruments
    (instrument only
      (chordsize %d %d)
      (performance (normal))
      (dynamics (mf))
      (pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch %d)))
      (durations 0.1 1.0)))
  (instrument-table (0))

  (entrydelays (0.5))
  (entrydelay-table (0))

  (durations (0.2))
  (duration-table (0))

  (registers ((pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch %d)))))
  (register-table (0))

  (harmony
    (principle interval)
    (matrix %s)
    %s)

  (principles
    (instrument (ensemble series) (order series))
    (entrydelay (ensemble series) (order series))
    (performance (ensemble series) (order series) (mode per-chord))
    (dynamics (ensemble series) (order series) (mode per-chord))
    (duration (ensemble series) (order series) (relation (independent per-chord)))
    (register (ensemble series) (order series) (mode per-chord)))

  (hierarchy (Ins Reg Har Per Dyn Ent Dur))
  (union none)
  (density %s)
)|}
      tr chordsize chordsize tr tr matrix_sexp forbidden_sexp density_sexp
  in
  match Pr26.Sexp.of_string src with
  | Error e -> failwith ("interval test formula failed to parse: " ^ e)
  | Ok sexps -> (
      match Pr26.Structure_formula.Parse.of_sexp sexps with
      | Error (errors, _) ->
          failwith
            (Printf.sprintf "interval test formula failed to build: %d error(s)"
               (List.length errors))
      | Ok (sf, _warnings) -> sf)

let steps_in_order (variants : Pr26.Score_generation.entry list list list) =
  variants
  |> List.concat_map (fun layers ->
         layers
         |> List.concat_map (fun (entries : Pr26.Score_generation.entry list) ->
                entries
                |> List.concat_map (fun (e : Pr26.Score_generation.entry) ->
                       e.notes
                       |> List.map (fun (n : Pr26.Score_generation.note) ->
                              match n.pitch with
                              | Pitched { step = Step s; _ } -> s
                              | Percussion ->
                                  failwith "unexpected percussion in interval test"))))

(* One tone per chord tone, ignoring the entry-point boundary (no "per
   chord" mode exists for either HARMONY principle - see the ROW fix earlier
   this session): a fixed-size-3 chord under [Autonomous] density, and the
   sparse adjacency matrix already hand-verified against the manual's own
   worked example. Every consecutive pair in the resolved sequence (notes
   within a chord *and* across chord boundaries alike) must be an allowed
   transition, and at least one chord's own notes must actually differ from
   one another - proving the chain runs through the chord rather than
   sharing one shared value for it. *)
let () =
  let sf =
    build_interval_formula ~tr:12 ~chordsize:3
      ~matrix_sexp:"(adjacency (1 (1 2)) (2 (1 3)) (3 (4)) (4 (1 4)))"
      ~forbidden_sexp:"" ~density_sexp:"(autonomous (low 3) (high 3) (principle (group (element series) (repetition series) (repetitions 1 4))))"
  in
  let variants = Pr26.Score_generation.build_score sf in
  let steps = steps_in_order variants |> Array.of_list in
  let tr = 12 in
  let interval_between a b = ((b - a) mod tr + tr) mod tr in
  let allowed = [ (1, 1); (1, 2); (2, 1); (2, 3); (3, 4); (4, 1); (4, 4) ] in
  (* Walk consecutive *intervals* (not tones - transposition is relative):
     the interval from steps.(i) to steps.(i+1) must be allowed to precede
     the interval from steps.(i+1) to steps.(i+2). *)
  let intervals =
    Array.init (Array.length steps - 1) (fun i ->
        interval_between steps.(i) steps.(i + 1))
  in
  for i = 0 to Array.length intervals - 2 do
    assert (List.mem (intervals.(i), intervals.(i + 1)) allowed)
  done;
  (* first chord = first 3 steps; assert they aren't all identical *)
  let first_chord = [ steps.(0); steps.(1); steps.(2) ] in
  assert (List.sort_uniq compare first_chord <> [ steps.(0) ]);
  print_endline "interval principle: per-chord-tone distribution test passed"

(* [instrument_repeated] regression (EMR-3 8.16): two equally-eligible
   single-note instruments and a chord density of 2 - the ensemble must
   always be able to find the *other* instrument for the chord's second
   note, so [instrument_repeated] must never fire just because chance alone
   might otherwise land twice on the same one while an alternative sat
   unused ([instrument] ensemble is [alea], which samples independently each
   time and so could repeat by pure chance without the fix). *)
let () =
  let src =
    {|(structure-formula
  (seed 3)
  (variant-duration 5.0)
  (octave-division 12)

  (dynamics (mf))
  (dynamics-table (0))

  (performance (normal))
  (performance-table (0))

  (number-of-instrument-groups 1)
  (instruments
    (instrument a
      (chordsize 1 1)
      (performance (normal))
      (dynamics (mf))
      (pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch 12)))
      (durations 0.1 1.0))
    (instrument b
      (chordsize 1 1)
      (performance (normal))
      (dynamics (mf))
      (pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch 12)))
      (durations 0.1 1.0)))
  (instrument-table (0 1))

  (entrydelays (0.5))
  (entrydelay-table (0))

  (durations (0.2))
  (duration-table (0))

  (registers ((pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch 12)))))
  (register-table (0))

  (harmony
    (principle interval)
    (matrix (adjacency (1 (1 2 3 4 5 6 7 8 9 10 11 12)) (2 (1 2 3 4 5 6 7 8 9 10 11 12)) (3 (1 2 3 4 5 6 7 8 9 10 11 12)) (4 (1 2 3 4 5 6 7 8 9 10 11 12)) (5 (1 2 3 4 5 6 7 8 9 10 11 12)) (6 (1 2 3 4 5 6 7 8 9 10 11 12)) (7 (1 2 3 4 5 6 7 8 9 10 11 12)) (8 (1 2 3 4 5 6 7 8 9 10 11 12)) (9 (1 2 3 4 5 6 7 8 9 10 11 12)) (10 (1 2 3 4 5 6 7 8 9 10 11 12)) (11 (1 2 3 4 5 6 7 8 9 10 11 12)) (12 (1 2 3 4 5 6 7 8 9 10 11 12)))))

  (principles
    (instrument (ensemble alea) (order series))
    (entrydelay (ensemble series) (order series))
    (performance (ensemble series) (order series) (mode per-chord))
    (dynamics (ensemble series) (order series) (mode per-chord))
    (duration (ensemble series) (order series) (relation (independent per-chord)))
    (register (ensemble series) (order series) (mode per-chord)))

  (hierarchy (Ins Reg Har Per Dyn Ent Dur))
  (union none)
  (density (autonomous (low 2) (high 2) (principle (group (element series) (repetition series) (repetitions 1 4)))))
)|}
  in
  match Pr26.Sexp.of_string src with
  | Error e ->
      failwith ("instrument_repeated test formula failed to parse: " ^ e)
  | Ok sexps -> (
      match Pr26.Structure_formula.Parse.of_sexp sexps with
      | Error (errors, _) ->
          failwith
            (Printf.sprintf
               "instrument_repeated test formula failed to build: %d error(s)"
               (List.length errors))
      | Ok (sf, _warnings) ->
          let variants = Pr26.Score_generation.build_score sf in
          let entries =
            variants
            |> List.concat_map (fun layers ->
                   layers
                   |> List.concat_map
                        (fun (es : Pr26.Score_generation.entry list) -> es))
          in
          assert (entries <> []);
          List.iter
            (fun (e : Pr26.Score_generation.entry) ->
              assert (not e.instrument_repeated))
            entries;
          print_endline
            "autonomous density: an unused compatible instrument is always \
             preferred, instrument_repeated test passed")

(* Genuine shortage (EMR-3 8.16): the same setup but with only *one*
   available instrument - the second note of every chord has no choice but
   to reuse it, and [instrument_repeated] must still fire, since this time
   the orchestra really has run out of distinct instruments. *)
let () =
  let src =
    {|(structure-formula
  (seed 3)
  (variant-duration 5.0)
  (octave-division 12)

  (dynamics (mf))
  (dynamics-table (0))

  (performance (normal))
  (performance-table (0))

  (number-of-instrument-groups 1)
  (instruments
    (instrument a
      (chordsize 1 1)
      (performance (normal))
      (dynamics (mf))
      (pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch 12)))
      (durations 0.1 1.0)))
  (instrument-table (0))

  (entrydelays (0.5))
  (entrydelay-table (0))

  (durations (0.2))
  (duration-table (0))

  (registers ((pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch 12)))))
  (register-table (0))

  (harmony
    (principle interval)
    (matrix (adjacency (1 (1 2 3 4 5 6 7 8 9 10 11 12)) (2 (1 2 3 4 5 6 7 8 9 10 11 12)) (3 (1 2 3 4 5 6 7 8 9 10 11 12)) (4 (1 2 3 4 5 6 7 8 9 10 11 12)) (5 (1 2 3 4 5 6 7 8 9 10 11 12)) (6 (1 2 3 4 5 6 7 8 9 10 11 12)) (7 (1 2 3 4 5 6 7 8 9 10 11 12)) (8 (1 2 3 4 5 6 7 8 9 10 11 12)) (9 (1 2 3 4 5 6 7 8 9 10 11 12)) (10 (1 2 3 4 5 6 7 8 9 10 11 12)) (11 (1 2 3 4 5 6 7 8 9 10 11 12)) (12 (1 2 3 4 5 6 7 8 9 10 11 12)))))

  (principles
    (instrument (ensemble alea) (order series))
    (entrydelay (ensemble series) (order series))
    (performance (ensemble series) (order series) (mode per-chord))
    (dynamics (ensemble series) (order series) (mode per-chord))
    (duration (ensemble series) (order series) (relation (independent per-chord)))
    (register (ensemble series) (order series) (mode per-chord)))

  (hierarchy (Ins Reg Har Per Dyn Ent Dur))
  (union none)
  (density (autonomous (low 2) (high 2) (principle (group (element series) (repetition series) (repetitions 1 4)))))
)|}
  in
  match Pr26.Sexp.of_string src with
  | Error e ->
      failwith ("instrument_repeated shortage test formula failed to parse: " ^ e)
  | Ok sexps -> (
      match Pr26.Structure_formula.Parse.of_sexp sexps with
      | Error (errors, _) ->
          failwith
            (Printf.sprintf
               "instrument_repeated shortage test formula failed to build: %d \
                error(s)"
               (List.length errors))
      | Ok (sf, _warnings) ->
          let variants = Pr26.Score_generation.build_score sf in
          let entries =
            variants
            |> List.concat_map (fun layers ->
                   layers
                   |> List.concat_map
                        (fun (es : Pr26.Score_generation.entry list) -> es))
          in
          assert (entries <> []);
          assert (
            List.for_all
              (fun (e : Pr26.Score_generation.entry) -> e.instrument_repeated)
              entries);
          print_endline
            "autonomous density: a genuine instrument shortage still flags \
             instrument_repeated test passed")

(* XCL-FRQ (entry 23): a forbidden tone must never appear, however long the
   run - checked against a fully-connected matrix so nothing else would ever
   exclude it. *)
let () =
  let fully_connected =
    let succs = "(1 2 3 4 5 6 7 8 9 10 11)" in
    "(adjacency"
    ^ String.concat ""
        (List.init 11 (fun i -> Printf.sprintf " (%d %s)" (i + 1) succs))
    ^ ")"
  in
  let sf =
    build_interval_formula ~tr:12 ~chordsize:1 ~matrix_sexp:fully_connected
      ~forbidden_sexp:"(forbidden-tones (7))" ~density_sexp:"instrument-density"
  in
  let variants = Pr26.Score_generation.build_score sf in
  let steps = steps_in_order variants in
  assert (not (List.mem 7 steps));
  print_endline "interval principle: forbidden-tones test passed"

(* Postponement (condition 3): with a fully-connected matrix (so nothing
   else constrains the choice) and no forbidden tones, the first
   [tr] draws - one full "producible" cycle - must be [tr] pairwise
   distinct tones, before any repeat becomes possible. *)
let () =
  let fully_connected =
    "(adjacency (1 (1 2 3)) (2 (1 2 3)) (3 (1 2 3)))"
  in
  let sf =
    build_interval_formula ~tr:4 ~chordsize:1 ~matrix_sexp:fully_connected
      ~forbidden_sexp:"" ~density_sexp:"instrument-density"
  in
  let variants = Pr26.Score_generation.build_score sf in
  let steps = steps_in_order variants in
  let first_cycle = List.filteri (fun i _ -> i < 4) steps in
  assert (List.length (List.sort_uniq compare first_cycle) = 4);
  print_endline "interval principle: postponement test passed"

(* "INTERVAL RESTRICTIONS TOO STRICT" (the manual's own acknowledged
   fallback): tr=2 leaves only interval 1 in the matrix's domain; forbidding
   tone 2 means the *only* reachable tone from tone 1 is always forbidden -
   deterministically hitting the fallback on every other note, never
   crashing or looping. *)
let () =
  let sf =
    build_interval_formula ~tr:2 ~chordsize:1
      ~matrix_sexp:"(adjacency (1 (1)))" ~forbidden_sexp:"(forbidden-tones (2))"
      ~density_sexp:"instrument-density"
  in
  let variants = Pr26.Score_generation.build_score sf in
  let notes =
    variants
    |> List.concat_map (fun layers ->
           layers
           |> List.concat_map (fun (entries : Pr26.Score_generation.entry list) ->
                  entries
                  |> List.concat_map (fun (e : Pr26.Score_generation.entry) ->
                         e.notes)))
  in
  assert (
    List.exists
      (fun (n : Pr26.Score_generation.note) -> not n.diagnostics.harmony_matrix_ok)
      notes);
  print_endline "interval principle: too-strict fallback test passed"

(* ---- HARMONY's CHORD principle (EMR-3 8.2, entries 15-18) ---- *)

(* [transpose_chord]: "chords starting with 0 are excluded from
   transposition, regardless of the numbers which follow" - a whole-chord
   property; zeros *within* an otherwise-transposable chord stay inert. *)
let () =
  let open Pr26.Parameters in
  let tr = 12 in
  let c1 = Result.get_ok (mk_chord ~tr [ Some 1; Some 3; Some 5 ]) in
  let c2 = Result.get_ok (mk_chord ~tr [ None; Some 3; Some 5 ]) in
  let c3 = Result.get_ok (mk_chord ~tr [ Some 1; None; Some 5 ]) in
  let to_ints (Chord arr) = Array.to_list arr |> List.map row_value_to_int in
  assert (to_ints (transpose_chord ~tr 2 c1) = [ 3; 5; 7 ]);
  assert (to_ints (transpose_chord ~tr 2 c2) = to_ints c2);
  assert (to_ints (transpose_chord ~tr 2 c3) = [ 3; 0; 7 ]);
  print_endline "transpose_chord: all tests passed"

(* Cumulative, not compounding (mirrors [row_stream]'s own regression shape
   for ROW): two passes through a 2-chord table under [ChordTransposeSeries]
   with a deterministic [Sequence] order - pass 2's chords must equal pass
   1's chords each transposed by the *same* single interval (drawn from the
   ORIGINAL reference table, never compounded against an already-transposed
   intermediate pass). *)
let () =
  let open Pr26.Parameters in
  let open Pr26.Score_generation in
  let tr = 12 in
  let table =
    Result.get_ok
      (mk_chord_table ~tr [ [ Some 1; Some 3 ]; [ Some 2; Some 5 ] ])
  in
  let harmony =
    HarmChord
      {
        table;
        order = Pr26.Selection.Sequence [ 0; 1 ];
        transposition = ChordTransposeSeries;
      }
  in
  let to_ints (Chord arr) = Array.to_list arr |> List.map row_value_to_int in
  let state0 = initial_har_state ~tr harmony in
  let c1, state1 = chord_next state0 in
  let c2, state2 = chord_next state1 in
  let c3, state3 = chord_next state2 in
  let c4, _ = chord_next state3 in
  assert (to_ints c1 = [ 1; 3 ]);
  assert (to_ints c2 = [ 2; 5 ]);
  let k = ((List.hd (to_ints c3) - 1) - (List.hd (to_ints c1) - 1) + tr) mod tr in
  let transpose_by k ns = List.map (fun n -> ((n - 1 + k) mod tr) + 1) ns in
  assert (to_ints c3 = transpose_by k (to_ints c1));
  assert (to_ints c4 = transpose_by k (to_ints c2));
  print_endline "chord_next: cumulative-not-compounding test passed"

(* [ChordTransposeGiven]: distinct from ROW's "serial" mode (which reuses
   the row's own tones) - a separately-authored explicit list, cycled once
   per completed pass and applied cumulatively to the ORIGINAL table, mod
   tr. 3-chord table, given intervals (2 5): pass 1 untransposed, pass 2 by
   2, pass 3 by (2+5) mod 12 = 7 - not by 5 alone, proving accumulation. *)
let () =
  let open Pr26.Parameters in
  let open Pr26.Score_generation in
  let tr = 12 in
  let table =
    Result.get_ok (mk_chord_table ~tr [ [ Some 1 ]; [ Some 2 ]; [ Some 3 ] ])
  in
  let transposition = Result.get_ok (mk_chord_transposition_given ~tr [ 2; 5 ]) in
  let harmony =
    HarmChord { table; order = Pr26.Selection.Sequence [ 0; 1; 2 ]; transposition }
  in
  let to_ints (Chord arr) = Array.to_list arr |> List.map row_value_to_int in
  let rec draw_n n state acc =
    if n = 0 then List.rev acc
    else
      let c, state' = chord_next state in
      draw_n (n - 1) state' (to_ints c :: acc)
  in
  let results = draw_n 9 (initial_har_state ~tr harmony) [] in
  assert (
    results
    = [ [ 1 ]; [ 2 ]; [ 3 ]; [ 3 ]; [ 4 ]; [ 5 ]; [ 8 ]; [ 9 ]; [ 10 ] ]);
  print_endline "chord_next: ChordTransposeGiven cycling test passed"

(* End-to-end CHORD tests. Two instruments (one pitched, one percussion) and
   two registers (likewise) - [alea] for instrument/register order, not
   [series]: with a predicate as restrictive as percussion-vs-pitched
   agreement and only one instrument/register of each kind, [series]' own
   "search only the currently-remaining, not-yet-drawn options" semantics
   can narrow to the wrong-type remainder before a reshuffle - a real,
   pre-existing characteristic of [series_draw_predicate] (shared by every
   parameter, not introduced by CHORD), simply never exercised this hard
   before since [Ins] never conditioned on harmony until now. [Alea]
   searches its full pool on every draw, so it isn't affected. *)
let build_chord_formula ~tr ~chords_sexp ~order_sexp ~transposition_sexp
    ~hierarchy_sexp ~density_sexp =
  let src =
    Printf.sprintf
      {|(structure-formula
  (seed 5)
  (variant-duration 8.0)
  (octave-division %d)

  (dynamics (mf))
  (dynamics-table (0))

  (performance (normal))
  (performance-table (0))

  (number-of-instrument-groups 1)
  (instruments
    (instrument piano
      (chordsize 1 2)
      (performance (normal))
      (dynamics (mf))
      (pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch %d)))
      (durations 0.1 1.0))
    (instrument drum
      (chordsize 1 2)
      (performance (normal))
      (dynamics (mf))
      (pitch-range percussion)
      (durations 0.1 1.0)))
  (instrument-table (0 1))

  (entrydelays (0.5))
  (entrydelay-table (0))

  (durations (0.2))
  (duration-table (0))

  (registers (
    (pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch %d)))
    (pitch-range percussion)))
  (register-table (0 1))

  (harmony
    (principle chord)
    (chords %s)
    (order %s)
    (transposition %s))

  (principles
    (instrument (ensemble (sequence 0)) (order alea))
    (entrydelay (ensemble (sequence 0)) (order series))
    (performance (ensemble (sequence 0)) (order series) (mode per-chord))
    (dynamics (ensemble series) (order series) (mode per-chord))
    (duration (ensemble (sequence 0)) (order series) (relation (independent per-note)))
    (register (ensemble (sequence 0)) (order alea) (mode per-note)))

  (hierarchy %s)
  (union none)
  (density %s)
)|}
      tr tr tr chords_sexp order_sexp transposition_sexp hierarchy_sexp
      density_sexp
  in
  match Pr26.Sexp.of_string src with
  | Error e -> Error [ "parse error: " ^ e ]
  | Ok sexps -> (
      match Pr26.Structure_formula.Parse.of_sexp sexps with
      | Error (errors, _) ->
          Error (errors |> List.map (fun (d : Pr26.Parameters.diagnostic) -> Pr26.Parameters.problem_id d.problem))
      | Ok (sf, _warnings) -> Ok sf)

let build_chord_formula_ok ~tr ~chords_sexp ~order_sexp ~transposition_sexp
    ~hierarchy_sexp ~density_sexp =
  match
    build_chord_formula ~tr ~chords_sexp ~order_sexp ~transposition_sexp
      ~hierarchy_sexp ~density_sexp
  with
  | Ok sf -> sf
  | Error ids ->
      failwith
        (Printf.sprintf "chord test formula failed to build: %s"
           (String.concat ", " ids))

(* EMR-3 §9.2: "the vertical density is identical to the size of the chord
   selected for each entry point" - [density] is genuinely superseded, not
   just ignored-but-coincidentally-matching. A 2-chord table with distinct
   sizes (2 and 4), drawn in a fixed alternating [Sequence] order: every
   entry's note count must alternate 2, 4, 2, 4, ... *)
let () =
  let sf =
    build_chord_formula_ok ~tr:12
      ~chords_sexp:"((1 3) (2 5 8 11))"
      ~order_sexp:"(sequence (0 1))" ~transposition_sexp:"none"
      ~hierarchy_sexp:"(Har Ins Reg Per Dyn Ent Dur)"
      ~density_sexp:"chord-density"
  in
  let variants = Pr26.Score_generation.build_score sf in
  let entries =
    variants
    |> List.concat_map (fun layers ->
           layers |> List.concat_map (fun (es : Pr26.Score_generation.entry list) -> es))
  in
  assert (List.length entries >= 4);
  let counts = entries |> List.map (fun (e : Pr26.Score_generation.entry) -> List.length e.notes) in
  List.iteri
    (fun i n -> assert (n = if i mod 2 = 0 then 2 else 4))
    counts;
  print_endline "chord principle: chord-size-drives-density test passed"

(* A chord mixing percussion and pitched tones (EMR-3 8.16: percussion
   instruments "can participate in the 'scoring' of the vertical density"
   alongside melody ones) - every percussion-flagged note must come from
   the percussion instrument with a [Percussion] pitch, and every pitched
   note must come from the pitched instrument with a real relative pitch
   drawn from the chord's own (untransposed - it starts with "p") tones. *)
let () =
  let sf =
    build_chord_formula_ok ~tr:12 ~chords_sexp:"((p 3 7))" ~order_sexp:"alea"
      ~transposition_sexp:"none"
      ~hierarchy_sexp:"(Har Ins Reg Per Dyn Ent Dur)"
      ~density_sexp:"chord-density"
  in
  let variants = Pr26.Score_generation.build_score sf in
  let notes =
    variants
    |> List.concat_map (fun layers ->
           layers
           |> List.concat_map (fun (es : Pr26.Score_generation.entry list) ->
                  es
                  |> List.concat_map (fun (e : Pr26.Score_generation.entry) -> e.notes)))
  in
  assert (notes <> []);
  List.iter
    (fun (n : Pr26.Score_generation.note) ->
      let (Pr26.Parameters.InstrumentName name) = n.instrument in
      match n.pitch with
      | Pr26.Parameters.Percussion -> assert (name = "drum")
      | Pr26.Parameters.Pitched { step = Step s; _ } ->
          assert (name = "piano");
          assert (s = 3 || s = 7))
    notes;
  assert (
    List.exists
      (fun (n : Pr26.Score_generation.note) -> n.pitch = Pr26.Parameters.Percussion)
      notes);
  print_endline "chord principle: mixed percussion/pitched chord test passed"

(* HARMONY must be first in the hierarchy under CHORD (EMR-3 §9.2: HARMONY
   is main parameter) - mirrors [InstrumentDensityRequiresInsFirst]. *)
let () =
  (match
     build_chord_formula ~tr:12 ~chords_sexp:"((1 3))" ~order_sexp:"alea"
       ~transposition_sexp:"none"
       ~hierarchy_sexp:"(Ins Har Reg Per Dyn Ent Dur)"
       ~density_sexp:"chord-density"
   with
  | Ok _ -> assert false
  | Error ids -> assert (List.mem "harmony-requires-har-first" ids));
  print_endline "chord principle: hierarchy validation test passed"

(* CHORD principle and chord-density must always agree, in both directions. *)
let () =
  (match
     build_chord_formula ~tr:12 ~chords_sexp:"((1 3))" ~order_sexp:"alea"
       ~transposition_sexp:"none"
       ~hierarchy_sexp:"(Har Ins Reg Per Dyn Ent Dur)"
       ~density_sexp:"instrument-density"
   with
  | Ok _ -> assert false
  | Error ids -> assert (List.mem "chord-principle-density-mismatch" ids));
  print_endline "chord principle: density/principle consistency test passed"

(* Empty/oversized chord table. *)
let () =
  (match
     build_chord_formula ~tr:12 ~chords_sexp:"()" ~order_sexp:"alea"
       ~transposition_sexp:"none"
       ~hierarchy_sexp:"(Har Ins Reg Per Dyn Ent Dur)"
       ~density_sexp:"chord-density"
   with
  | Ok _ -> assert false
  | Error ids -> assert (List.mem "empty-chord-table" ids));
  (match
     build_chord_formula ~tr:12
       ~chords_sexp:"((1 2 3 4 5 6 7 8 9 10 11 12 1))" ~order_sexp:"alea"
       ~transposition_sexp:"none"
       ~hierarchy_sexp:"(Har Ins Reg Per Dyn Ent Dur)"
       ~density_sexp:"chord-density"
   with
  | Ok _ -> assert false
  | Error ids -> assert (List.mem "chord-too-long" ids));
  print_endline "chord principle: empty/oversized chord table test passed"

(* ---- union = common-harmony (EMR-3 6.2's "s=1") ---- *)

(* A row of 4 distinct pitches, transposition none (so the row_stream just
   repeats [1;2;3;4;1;2;3;4;...] forever) - deliberately simple so a
   "which position in the cycle is this" check is a one-line assertion.
   [n_groups]/[instrument_table_sexp]/[entrydelays_sexp]/
   [entrydelay_table_sexp] let the 2-layer interleaving tests and the
   1-layer regression test share one template; entry delay is combined
   1:1 with the instrument groups so each layer gets its own constant,
   deterministic entry delay (and thus fully predictable, distinct
   per-layer absolute times) rather than an ensemble-shuffled one. *)
let common_harmony_formula_sexp ~union_sexp ~n_groups ~instrument_table_sexp
    ~entrydelays_sexp ~entrydelay_table_sexp ~hierarchy_sexp =
  Printf.sprintf
    {|(structure-formula
  (seed 5)
  (variant-duration 2.0)
  (n-variants 1)
  (octave-division 12)

  (dynamics (mf))
  (dynamics-table (0))

  (performance (normal))
  (performance-table (0))

  (number-of-instrument-groups %d)
  (instruments
    (instrument only
      (chordsize 1 1)
      (performance (normal))
      (dynamics (mf))
      (pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch 12)))
      (durations 0.1 1.0)))
  (instrument-table %s)

  (entrydelays %s)
  (entrydelay-table %s)

  (durations (0.2))
  (duration-table (0))

  (registers ((pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch 12)))))
  (register-table (0))

  (harmony
    (principle row)
    (row (1 2 3 4))
    (transposition none))

  (principles
    (instrument (ensemble series) (order series))
    (entrydelay (ensemble combination) (order series))
    (performance (ensemble series) (order series) (mode per-chord))
    (dynamics (ensemble series) (order series) (mode per-chord))
    (duration (ensemble series) (order series) (relation (independent per-chord)))
    (register (ensemble series) (order series) (mode per-chord)))

  (hierarchy %s)
  (union %s)
  (density instrument-density)
)|}
    n_groups instrument_table_sexp entrydelays_sexp entrydelay_table_sexp
    hierarchy_sexp union_sexp

let build_common_harmony_formula ~union_sexp ~n_groups ~instrument_table_sexp
    ~entrydelays_sexp ~entrydelay_table_sexp ~hierarchy_sexp =
  let src =
    common_harmony_formula_sexp ~union_sexp ~n_groups ~instrument_table_sexp
      ~entrydelays_sexp ~entrydelay_table_sexp ~hierarchy_sexp
  in
  match Pr26.Sexp.of_string src with
  | Error e -> Error [ "parse error: " ^ e ]
  | Ok sexps -> (
      match Pr26.Structure_formula.Parse.of_sexp sexps with
      | Error (errors, _) ->
          Error
            (errors
            |> List.map (fun (d : Pr26.Parameters.diagnostic) ->
                   Pr26.Parameters.problem_id d.problem))
      | Ok (sf, _warnings) -> Ok sf)

let two_layer_common_harmony_formula ~union_sexp =
  match
    build_common_harmony_formula ~union_sexp ~n_groups:2
      ~instrument_table_sexp:"(0) (0)" ~entrydelays_sexp:"(0.5 0.3)"
      ~entrydelay_table_sexp:"(0) (1)"
      ~hierarchy_sexp:"(Ins Reg Per Dyn Ent Dur Har)"
  with
  | Ok sf -> sf
  | Error ids ->
      failwith
        (Printf.sprintf "common-harmony test formula failed to build: %s"
           (String.concat ", " ids))

(* Flattens one variant's layers into (time, layer_idx) - tagged steps,
   sorted by (time, layer_idx) - the same tie-break
   [compare_common_harmony_groups] uses internally - so the test can read
   notes off in true chronological order regardless of which layer produced
   them, without needing to hand-predict exact absolute times. *)
let true_time_order_steps (layers : Pr26.Score_generation.entry list list) =
  layers
  |> List.mapi (fun layer_idx entries ->
         entries
         |> List.concat_map (fun (e : Pr26.Score_generation.entry) ->
                e.notes
                |> List.map (fun (n : Pr26.Score_generation.note) ->
                       match n.pitch with
                       | Pitched { step = Step s; _ } -> (e.time, layer_idx, s)
                       | Percussion -> failwith "unexpected percussion")))
  |> List.concat |> List.sort compare
  |> List.map (fun (_, _, s) -> s)

let row_next n = (n mod 4) + 1

let is_unbroken_cycle steps =
  let rec go = function
    | a :: (b :: _ as rest) -> b = row_next a && go rest
    | _ -> true
  in
  go steps

(* The load-bearing test: with 2 layers whose entries deliberately
   interleave in real time (layer A ticks every 0.5s, layer B every 0.3s),
   union = common-harmony must produce one unbroken walk through the row
   when notes are read back in TRUE chronological order, regardless of
   which layer produced each one - proving harmony is a single continuous
   stream across the merged timeline, not one stream per layer. *)
let () =
  let sf = two_layer_common_harmony_formula ~union_sexp:"common-harmony" in
  let variants = Pr26.Score_generation.build_score sf in
  assert (List.length variants = 1);
  let layers = List.hd variants in
  assert (List.length layers = 2);
  let steps = true_time_order_steps layers in
  assert (List.length steps >= 8);
  assert (is_unbroken_cycle steps);
  print_endline
    "union common-harmony: true-chronological cross-layer harmony test \
     passed"

(* The precise contrast: the *same* formula under union = none (s=2,
   "harmony per layer") must NOT show that same unbroken pattern when read
   in the same true-time order, since each layer ran its own independent
   pass through the row (both starting the row over from the top, since
   [har_state] still threads across layers in layer-declaration order, not
   time order). Also checks conservation: the same total note count comes
   out of both runs for the same seed - the merge/split roundtrip drops or
   duplicates nothing. *)
let () =
  let sf_common = two_layer_common_harmony_formula ~union_sexp:"common-harmony" in
  let sf_none = two_layer_common_harmony_formula ~union_sexp:"none" in
  let layers_common = List.hd (Pr26.Score_generation.build_score sf_common) in
  let layers_none = List.hd (Pr26.Score_generation.build_score sf_none) in
  let steps_none = true_time_order_steps layers_none in
  assert (not (is_unbroken_cycle steps_none));
  let total_notes layers =
    layers
    |> List.concat_map (fun (es : Pr26.Score_generation.entry list) ->
           es |> List.concat_map (fun (e : Pr26.Score_generation.entry) -> e.notes))
    |> List.length
  in
  assert (total_notes layers_common = total_notes layers_none);
  print_endline
    "union common-harmony vs none: contrast and conservation test passed"

(* Single-layer regression: with nothing to interleave, the merge/split
   machinery must degenerate to an identity transform - common-harmony and
   per-layer must produce byte-identical output for the same seed. *)
let () =
  let one_layer ~union_sexp =
    match
      build_common_harmony_formula ~union_sexp ~n_groups:1
        ~instrument_table_sexp:"(0)" ~entrydelays_sexp:"(0.5)"
        ~entrydelay_table_sexp:"(0)"
        ~hierarchy_sexp:"(Ins Reg Per Dyn Ent Dur Har)"
    with
    | Ok sf -> sf
    | Error ids ->
        failwith
          (Printf.sprintf "common-harmony test formula failed to build: %s"
             (String.concat ", " ids))
  in
  let layers_common =
    List.hd (Pr26.Score_generation.build_score (one_layer ~union_sexp:"common-harmony"))
  in
  let layers_none =
    List.hd (Pr26.Score_generation.build_score (one_layer ~union_sexp:"none"))
  in
  assert (layers_common = layers_none);
  print_endline "union common-harmony: single-layer regression test passed"

(* Grammar backward compatibility: (union none) must still mean exactly
   what it means today (s=2), and the new (union common-harmony) atom must
   parse. *)
let () =
  let sf_none =
    match
      build_common_harmony_formula ~union_sexp:"none" ~n_groups:1
        ~instrument_table_sexp:"(0)" ~entrydelays_sexp:"(0.5)"
        ~entrydelay_table_sexp:"(0)"
        ~hierarchy_sexp:"(Ins Reg Har Per Dyn Ent Dur)"
    with
    | Ok sf -> sf
    | Error ids -> failwith ("expected (union none) to parse: " ^ String.concat ", " ids)
  in
  assert (sf_none.union = Pr26.Structure_formula.NoUnionPerLayer);
  let sf_common =
    match
      build_common_harmony_formula ~union_sexp:"common-harmony" ~n_groups:1
        ~instrument_table_sexp:"(0)" ~entrydelays_sexp:"(0.5)"
        ~entrydelay_table_sexp:"(0)"
        ~hierarchy_sexp:"(Ins Reg Per Dyn Ent Dur Har)"
    with
    | Ok sf -> sf
    | Error ids ->
        failwith ("expected (union common-harmony) to parse: " ^ String.concat ", " ids)
  in
  assert (sf_common.union = Pr26.Structure_formula.NoUnionCommonHarmony);
  print_endline "union: grammar backward-compatibility test passed"

(* HARMONY must be last in the hierarchy under common-harmony (EMR-3 6.2's
   "s=1"). *)
let () =
  (match
     build_common_harmony_formula ~union_sexp:"common-harmony" ~n_groups:1
       ~instrument_table_sexp:"(0)" ~entrydelays_sexp:"(0.5)"
       ~entrydelay_table_sexp:"(0)"
       ~hierarchy_sexp:"(Ins Reg Har Per Dyn Ent Dur)"
   with
  | Ok _ -> assert false
  | Error ids -> assert (List.mem "harmony-requires-har-last" ids));
  (match
     build_common_harmony_formula ~union_sexp:"common-harmony" ~n_groups:1
       ~instrument_table_sexp:"(0)" ~entrydelays_sexp:"(0.5)"
       ~entrydelay_table_sexp:"(0)"
       ~hierarchy_sexp:"(Ins Reg Per Dyn Ent Dur Har)"
   with
  | Error ids ->
      failwith ("expected Har-last hierarchy to be valid: " ^ String.concat ", " ids)
  | Ok _ -> ());
  print_endline "union common-harmony: hierarchy validation test passed"

(* CHORD forces Har first (EMR-3 9.2); common-harmony forces Har last -
   mutually exclusive, rejected outright regardless of what the hierarchy
   says (a hierarchy satisfying CHORD's own Har-first rule must still be
   rejected, proving the check doesn't depend on hierarchy content). *)
let () =
  let src =
    {|(structure-formula
  (seed 5)
  (variant-duration 8.0)
  (octave-division 12)

  (dynamics (mf))
  (dynamics-table (0))

  (performance (normal))
  (performance-table (0))

  (number-of-instrument-groups 1)
  (instruments
    (instrument piano
      (chordsize 1 2)
      (performance (normal))
      (dynamics (mf))
      (pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch 12)))
      (durations 0.1 1.0)))
  (instrument-table (0))

  (entrydelays (0.5))
  (entrydelay-table (0))

  (durations (0.2))
  (duration-table (0))

  (registers ((pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch 12)))))
  (register-table (0))

  (harmony
    (principle chord)
    (chords ((1 3)))
    (order alea)
    (transposition none))

  (principles
    (instrument (ensemble (sequence 0)) (order alea))
    (entrydelay (ensemble (sequence 0)) (order series))
    (performance (ensemble (sequence 0)) (order series) (mode per-chord))
    (dynamics (ensemble series) (order series) (mode per-chord))
    (duration (ensemble (sequence 0)) (order series) (relation (independent per-note)))
    (register (ensemble (sequence 0)) (order alea) (mode per-note)))

  (hierarchy (Har Ins Reg Per Dyn Ent Dur))
  (union common-harmony)
  (density chord-density)
)|}
  in
  (match Pr26.Sexp.of_string src with
  | Error e -> failwith ("parse error: " ^ e)
  | Ok sexps -> (
      match Pr26.Structure_formula.Parse.of_sexp sexps with
      | Ok _ -> assert false
      | Error (errors, _) ->
          let ids =
            errors
            |> List.map (fun (d : Pr26.Parameters.diagnostic) ->
                   Pr26.Parameters.problem_id d.problem)
          in
          assert (List.mem "chord-principle-common-harmony-mismatch" ids)));
  print_endline
    "union common-harmony: CHORD-principle mismatch validation test passed"

(* ---- REST (EMR-3 7.4) ---- *)

(* A hand-built [duration sel_state] that always draws the same fixed
   value, regardless of principle-continuity questions - lets the direct
   [compute_rest_insertions] tests below hand-verify exact insertion
   points/times without depending on any other part of the pipeline. *)
let fixed_rest_state value =
  Pr26.Score_generation.sel_init (Pr26.Selection.Sequence [ 0 ]) 1
    (Pr26.Parameters.elements_of_array [| Pr26.Parameters.Duration value |])

(* Sound-entry vs. general-entry divergence, and the "recomputed against
   the current, already-shifted timeline" design: target 1 sustains from
   1.0 to 5.0, concealing target 2's onset at 2.0. Sound-entry mode doesn't
   care about sustain at all, so it gives every target its own rest.
   General-entry mode must skip target 2 (still concealed by target 1's
   sustain at the moment the search reaches it) and land on target 3
   instead - proving concealment is evaluated live during the walk, not
   from some list of "which targets are ever concealed" decided up front. *)
let () =
  let open Pr26.Score_generation in
  let targets =
    [|
      { time = 0.0; sustain_until = 0.0 };
      { time = 1.0; sustain_until = 5.0 };
      { time = 2.0; sustain_until = 2.0 };
      { time = 6.0; sustain_until = 6.0 };
    |]
  in
  let before_indices insertions =
    insertions |> List.map (fun (i : rest_insertion) -> i.before_index)
  in
  let sound_insertions, _ =
    compute_rest_insertions ~variant:0 ~layer:0 ~variant_duration:10.0
      ~rest_mode:(Pr26.Parameters.RestBeforeSoundEntry { d1 = 10.0; d2 = 10.0 })
      ~targets (fixed_rest_state 0.5)
  in
  assert (before_indices sound_insertions = [ 1; 2; 3 ]);
  let general_insertions, _ =
    compute_rest_insertions ~variant:0 ~layer:0 ~variant_duration:10.0
      ~rest_mode:
        (Pr26.Parameters.RestBeforeGeneralEntry { d1 = 10.0; d2 = 10.0 })
      ~targets (fixed_rest_state 0.5)
  in
  assert (before_indices general_insertions = [ 1; 3 ]);
  print_endline
    "compute_rest_insertions: sound-entry vs general-entry divergence test \
     passed"

(* Degenerate entry range (d1 = d2 = 0): the ALEA offset is exactly 0 every
   time, so a naive "resume the next search from [found_idx]" would let the
   very same target satisfy the search again forever. [idx] must advance to
   [found_idx + 1] regardless, so this always terminates, touching every
   target exactly once. The regression is really "this call returns at
   all" - the strictly-increasing/full-coverage assertions below are the
   easiest way to also confirm it did the *right* thing while it's at it. *)
let () =
  let open Pr26.Score_generation in
  let targets =
    [|
      { time = 0.0; sustain_until = 0.0 };
      { time = 1.0; sustain_until = 1.0 };
      { time = 2.0; sustain_until = 2.0 };
      { time = 3.0; sustain_until = 3.0 };
      { time = 10.0; sustain_until = 10.0 };
    |]
  in
  let insertions, _ =
    compute_rest_insertions ~variant:0 ~layer:0 ~variant_duration:5.0
      ~rest_mode:(Pr26.Parameters.RestBeforeSoundEntry { d1 = 0.0; d2 = 0.0 })
      ~targets (fixed_rest_state 1.0)
  in
  assert (List.length insertions = 5);
  let indices = insertions |> List.map (fun (i : rest_insertion) -> i.before_index) in
  assert (indices = [ 0; 1; 2; 3; 4 ]);
  print_endline
    "compute_rest_insertions: degenerate d1=d2=0 termination test passed"

(* Full-pipeline REST formula: one percussion instrument (avoids HARMONY/
   pitch complications entirely), fixed entry delay and duration so every
   entry's original (pre-rest) time is exactly predictable
   (0, entrydelay, 2*entrydelay, ...), and a single fixed rest length so
   the exact insertion point can be hand-derived from
   [rest_offset_draw]'s own formula. [rest] is [("", "")] for REST off, or
   a (principles-stanza, top-level-stanza) pair otherwise - mirrors
   [build_common_harmony_formula]'s own "assemble a template from
   parameters" shape. *)
let build_rest_formula ~variant_duration ~entrydelay ~duration ~n_groups
    ~instrument_table_sexp ~union_sexp ~rest =
  let principle_stanza, top_stanza = rest in
  let src =
    Printf.sprintf
      {|(structure-formula
  (seed 3)
  (variant-duration %f)
  (n-variants 1)
  (octave-division 12)

  (dynamics (mf))
  (dynamics-table (0))

  (performance (normal))
  (performance-table (0))

  (number-of-instrument-groups %d)
  (instruments
    (instrument only
      (chordsize 1 1)
      (performance (normal))
      (dynamics (mf))
      (pitch-range percussion)
      (durations 0.001 100.0)))
  (instrument-table %s)

  (entrydelays (%f))
  (entrydelay-table (0))

  (durations (%f))
  (duration-table (0))

  (registers ((pitch-range percussion)))
  (register-table (0))

  (harmony
    (principle row)
    (row (p))
    (transposition none))

  (principles
    (instrument (ensemble series) (order series))
    (entrydelay (ensemble series) (order series))
    (performance (ensemble series) (order series) (mode per-chord))
    (dynamics (ensemble series) (order series) (mode per-chord))
    (duration (ensemble series) (order series) (relation (independent per-chord)))
    (register (ensemble series) (order series) (mode per-chord))
    %s)

  (hierarchy (Ins Reg Har Per Dyn Ent Dur))
  %s
  (union %s)
  (density instrument-density)
)|}
      variant_duration n_groups instrument_table_sexp entrydelay duration
      principle_stanza top_stanza union_sexp
  in
  match Pr26.Sexp.of_string src with
  | Error e -> failwith ("REST test formula failed to parse: " ^ e)
  | Ok sexps -> (
      match Pr26.Structure_formula.Parse.of_sexp sexps with
      | Error (errors, _) ->
          failwith
            (Printf.sprintf "REST test formula failed to build: %s"
               (errors
               |> List.map (fun (d : Pr26.Parameters.diagnostic) ->
                      Pr26.Parameters.problem_id d.problem)
               |> String.concat ", "))
      | Ok (sf, _warnings) -> sf)

let rest_omitted = ("", "")
let rest_explicit_off = ("", "(rest-mode off)")

let rest_before_sound_entry ~d1 ~d2 ~rest_duration =
  ( "(rest (ensemble (sequence 0)) (order series))",
    Printf.sprintf
      "(rest-mode (before-sound-entry %f %f))\n  (rests (%f))\n  (rest-table \
       (0))"
      d1 d2 rest_duration )

(* REST off (whether the field is entirely absent, or explicitly written)
   must be a complete no-op: no entry is ever marked [is_rest], and the
   entry count/timing matches what the formula would produce with no REST
   machinery at all. *)
let () =
  let check ~rest =
    let sf =
      build_rest_formula ~variant_duration:8.0 ~entrydelay:1.0 ~duration:0.3
        ~n_groups:1 ~instrument_table_sexp:"(0)" ~union_sexp:"union" ~rest
    in
    let variants = Pr26.Score_generation.build_score sf in
    let entries = List.hd (List.hd variants) in
    assert (List.length entries = 8);
    assert (List.for_all (fun (e : Pr26.Score_generation.entry) -> not e.is_rest) entries);
    List.iteri
      (fun i (e : Pr26.Score_generation.entry) ->
        assert (Float.abs (e.time -. float_of_int i) < 1e-9))
      entries
  in
  check ~rest:rest_omitted;
  check ~rest:rest_explicit_off;
  print_endline "REST off: no-op test passed (field omitted and explicit)"

(* The load-bearing shift test: entries at 0..7 (entrydelay 1.0, 8 events),
   REST at (before-sound-entry 50.0 50.0) with variant_duration 8.0 draws a
   constant offset of 4.0 (50% of 8.0) from cursor 0.0 - so the first
   qualifying original entry is index 4 (time 4.0), and no further entry
   reaches the next provisional point (10.0) once shifted, so exactly one
   rest is placed. Checked for both [Union] (one merged layer) and
   [NoUnionPerLayer] (2 structurally-identical layers, each independently
   getting the same rest at the same position) - exercising both of
   [insert_rests_entries]'s call sites (3.6's [Union]/[NoUnionPerLayer]
   branches) with one hand-derived shape. *)
let () =
  let check_layer (entries : Pr26.Score_generation.entry list) =
    assert (List.length entries = 9);
    let expected_times = [ 0.0; 1.0; 2.0; 3.0; 4.0; 6.0; 7.0; 8.0; 9.0 ] in
    let expected_is_rest = [ false; false; false; false; true; false; false; false; false ] in
    List.iter2
      (fun (e : Pr26.Score_generation.entry) expected_t ->
        assert (Float.abs (e.time -. expected_t) < 1e-9))
      entries expected_times;
    List.iter2
      (fun (e : Pr26.Score_generation.entry) expected_r -> assert (e.is_rest = expected_r))
      entries expected_is_rest;
    let rest_entry = List.nth entries 4 in
    assert (rest_entry.notes = []);
    (match rest_entry.duration with
    | Some (Duration d) -> assert (Float.abs (d -. 2.0) < 1e-9)
    | None -> assert false)
  in
  let rest = rest_before_sound_entry ~d1:50.0 ~d2:50.0 ~rest_duration:2.0 in
  let sf_union =
    build_rest_formula ~variant_duration:8.0 ~entrydelay:1.0 ~duration:0.3
      ~n_groups:1 ~instrument_table_sexp:"(0)" ~union_sexp:"union" ~rest
  in
  check_layer (List.hd (List.hd (Pr26.Score_generation.build_score sf_union)));
  let sf_per_layer =
    build_rest_formula ~variant_duration:8.0 ~entrydelay:1.0 ~duration:0.3
      ~n_groups:2 ~instrument_table_sexp:"(0) (0)" ~union_sexp:"none" ~rest
  in
  let layers_per_layer = Pr26.Score_generation.build_score sf_per_layer |> List.hd in
  assert (List.length layers_per_layer = 2);
  List.iter check_layer layers_per_layer;
  print_endline
    "REST: rest shifts every following entry by exactly its own duration \
     (Union and NoUnionPerLayer) test passed"

(* union = common-harmony: REST must run per layer, between phase 1 and
   phase 2's merge (3.6's [NoUnionCommonHarmony] branch/[insert_rests_
   common_harmony_layer]) - checked structurally (at least one rest per
   layer, every layer's own entries still strictly ascending in time)
   rather than by hand-deriving exact positions, since phase 1's own
   per-layer event counts aren't as trivially predictable as the
   single-parameter formulas above. *)
let () =
  let src =
    {|(structure-formula
  (seed 5)
  (variant-duration 2.0)
  (n-variants 1)
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
      (pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch 12)))
      (durations 0.1 1.0)))
  (instrument-table (0) (0))

  (entrydelays (0.5 0.3))
  (entrydelay-table (0) (1))

  (durations (0.05))
  (duration-table (0))

  (registers ((pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch 12)))))
  (register-table (0))

  (harmony
    (principle row)
    (row (1 2 3 4))
    (transposition none))

  (rest-mode (before-sound-entry 20.0 20.0))
  (rests (0.1))
  (rest-table (0))

  (principles
    (instrument (ensemble series) (order series))
    (entrydelay (ensemble combination) (order series))
    (performance (ensemble series) (order series) (mode per-chord))
    (dynamics (ensemble series) (order series) (mode per-chord))
    (duration (ensemble series) (order series) (relation (independent per-chord)))
    (register (ensemble series) (order series) (mode per-chord))
    (rest (ensemble (sequence 0)) (order series)))

  (hierarchy (Ins Reg Per Dyn Ent Dur Har))
  (union common-harmony)
  (density instrument-density)
)|}
  in
  let sf =
    match Pr26.Sexp.of_string src with
    | Error e -> failwith ("parse error: " ^ e)
    | Ok sexps -> (
        match Pr26.Structure_formula.Parse.of_sexp sexps with
        | Error (errors, _) ->
            failwith
              (Printf.sprintf "common-harmony REST formula failed to build: %s"
                 (errors
                 |> List.map (fun (d : Pr26.Parameters.diagnostic) ->
                        Pr26.Parameters.problem_id d.problem)
                 |> String.concat ", "))
        | Ok (sf, _warnings) -> sf)
  in
  let layers = Pr26.Score_generation.build_score sf |> List.hd in
  assert (List.length layers = 2);
  List.iter
    (fun (entries : Pr26.Score_generation.entry list) ->
      assert (List.exists (fun (e : Pr26.Score_generation.entry) -> e.is_rest) entries);
      let rec ascending = function
        | (a : Pr26.Score_generation.entry) :: (b :: _ as rest) ->
            a.time <= b.time && ascending rest
        | _ -> true
      in
      assert (ascending entries))
    layers;
  print_endline
    "REST: union common-harmony per-layer insertion (phase 1 -> phase 2 \
     seam) test passed"

(* Pitch-range bounds (instrument and register) must stay within 1..tr. *)
let () =
  let src pitch =
    Printf.sprintf
      {|(structure-formula
  (seed 3) (variant-duration 5.0) (octave-division 12)
  (dynamics (mf)) (dynamics-table (0))
  (performance (normal)) (performance-table (0))
  (number-of-instrument-groups 1)
  (instruments
    (instrument a (chordsize 1 1) (performance (normal)) (dynamics (mf))
      (pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch %d)))
      (durations 0.1 1.0)))
  (instrument-table (0))
  (entrydelays (0.5)) (entrydelay-table (0))
  (durations (0.2)) (duration-table (0))
  (registers ((pitch-range (low (octave 1) (pitch 1)) (high (octave 8) (pitch 12)))))
  (register-table (0))
  (harmony (principle row) (row (1 2 3)) (transposition none))
  (principles
    (instrument (ensemble alea) (order series))
    (entrydelay (ensemble series) (order series))
    (performance (ensemble series) (order series) (mode per-chord))
    (dynamics (ensemble series) (order series) (mode per-chord))
    (duration (ensemble series) (order series) (relation (independent per-chord)))
    (register (ensemble series) (order series) (mode per-chord)))
  (hierarchy (Ins Reg Har Per Dyn Ent Dur))
  (union none)
  (density (autonomous (low 2) (high 2) (principle (group (element series) (repetition series) (repetitions 1 4))))))|}
      pitch
  in
  let has_relative_pitch_error pitch =
    match Pr26.Sexp.of_string (src pitch) with
    | Error _ -> false
    | Ok sexps -> (
        match Pr26.Structure_formula.Parse.of_sexp sexps with
        | Error (errors, _) ->
            List.exists
              (fun (e : Pr26.Parameters.diagnostic) ->
                (match e.problem with Pr26.Parameters.InvalidRelativePitch _ -> true | _ -> false))
              errors
        | Ok _ -> false)
  in
  assert (has_relative_pitch_error 13);
  print_endline "instrument pitch-range bound > tr rejected test passed"
