open Pr26.Parameters
open Pr26.Score_generation
open Pr26.Instrumented_selection
open Pr26.Selection
open Pr26.Debug_log

(* ---- Unit-level: SERIES restart detection + the opt-in contract ---- *)

let test_series_restart_and_opt_in () =
  let arr = elements_of_array [| "a"; "b"; "c" |] in
  let ctx = { variant = 0; layer = 0; seq = Resolved 0; param = PIns } in
  let state0 = sel_init Series 3 arr in
  let draw4 state0 =
    let _, s1 = sel_draw ~ctx state0 in
    let _, s2 = sel_draw ~ctx s1 in
    let _, s3 = sel_draw ~ctx s2 in
    let _, s4 = sel_draw ~ctx s3 in
    s4
  in
  (* Disabled: the exact same draw sequence produces zero events - the
     opt-in contract, not just that the flag exists. *)
  enabled := false;
  reset ();
  ignore (draw4 state0);
  assert (events () = []);
  (* Enabled: a 3-element SERIES exhausts its pool after 3 draws, so the
     4th (wrap-around) draw - and only that one - reports a restart. *)
  enabled := true;
  reset ();
  ignore (draw4 state0);
  (match events () with
  | [ SeriesRestart c ] -> assert (c = ctx)
  | _ -> assert false);
  enabled := false;
  print_endline "debug_log: series restart + opt-in test passed"

(* ---- End to end: entry/note id assignment through build_score, REST included ---- *)

(* [instrument-density], one layer, REST forced to fire at least once
   ([before-sound-entry] with [d1 = d2] makes the search offset
   deterministic - only the entries it searches against still depend on
   [Random], via entrydelay's own SERIES cycle). *)
let rest_test_formula_sexp =
  {|(structure-formula
  (seed 7)
  (variant-duration 5.0)
  (n-variants 1)
  (octave-division 12)

  (dynamics (mf))
  (dynamics-table (0))

  (performance (normal))
  (performance-table (0))

  (number-of-instrument-groups 1)
  (instruments
    (instrument only
      (chordsize 1 1)
      (performance (normal))
      (dynamics (mf))
      (pitch-range percussion)
      (durations 0.1 1.0)))
  (instrument-table (0))

  (entrydelays (0.1 0.15 0.2))
  (entrydelay-table (0 1 2))

  (durations (0.05))
  (duration-table (0))

  (registers ((pitch-range percussion)))
  (register-table (0))

  (rest-mode (before-sound-entry 20.0 20.0))
  (rests (0.05))
  (rest-table (0))

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
    (rest (ensemble alea) (order alea)))

  (hierarchy (Ins Reg Har Per Dyn Ent Dur))
  (union none)
  (density instrument-density)
)|}

let build_rest_test_formula () =
  match Pr26.Sexp.of_string rest_test_formula_sexp with
  | Error e -> failwith ("debug_log_test formula failed to parse: " ^ e)
  | Ok sexps -> (
      match Pr26.Structure_formula.Parse.of_sexp sexps with
      | Error (errors, _) ->
          failwith
            (Printf.sprintf "debug_log_test formula failed to build: %d error(s)"
               (List.length errors))
      | Ok (sf, _warnings) -> sf)

let test_entry_note_ids () =
  let sf = build_rest_test_formula () in
  let variants = build_score sf in
  assert (List.length variants = 1);
  let layers = List.hd variants in
  assert (List.length layers = 1);
  let entries = List.hd layers in
  (* Every entry claims variant 0 / layer 0 - the only ones this formula has. *)
  List.iter
    (fun (e : entry) -> assert (e.id.variant = 0 && e.id.layer = 0))
    entries;
  let resolved_ns =
    entries
    |> List.filter_map (fun (e : entry) ->
        match e.id.seq with Resolved n -> Some n | RestBefore _ -> None)
    |> List.sort compare
  in
  (* [Resolved n] is assigned once, in generation order, before any REST
     splicing - dense and unique regardless of how many rests end up
     interspersed among these entries afterward. *)
  assert (resolved_ns = List.init (List.length resolved_ns) (fun i -> i));
  let rest_befores =
    entries
    |> List.filter_map (fun (e : entry) ->
        match e.id.seq with RestBefore n -> Some n | Resolved _ -> None)
  in
  (* This formula's REST is configured to fire deterministically (fixed
     offset) - a vacuous "zero rests" run would defeat the point of this
     test. *)
  assert (rest_befores <> []);
  let resolved_set = List.sort_uniq compare resolved_ns in
  List.iter
    (fun n -> assert (List.mem n resolved_set))
    rest_befores;
  (* Every note's [of_entry] matches its owning entry's id, and note indices
     are dense/unique within that entry's own chord. *)
  List.iter
    (fun (e : entry) ->
      let note_ns =
        e.notes
        |> List.map (fun (n : note) ->
            assert (n.id.of_entry = e.id);
            n.id.note)
        |> List.sort compare
      in
      assert (note_ns = List.init (List.length note_ns) (fun i -> i)))
    entries;
  print_endline "debug_log: entry/note id assignment (with REST) test passed"

let () =
  test_series_restart_and_opt_in ();
  test_entry_note_ids ()
