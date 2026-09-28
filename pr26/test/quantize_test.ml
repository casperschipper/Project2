open Pr26.Parameters
open Pr26.Score_generation
open Pr26.Quantize

let q = Q.make
let settings = default_settings (* 4/4, sixteenths, tuplets up to 7 *)
let no_tuplets = { settings with tuplets = [] }

(* Onsets and durations as exact fractions, for readable assertions. *)
let quantized s events = fst (quantize_events s events)

let tree s events =
  let _, r = quantize_events s events in
  r.measures |> List.map (fun m -> division_to_string m.division)

let check name cond =
  if not cond then failwith ("quantize_test: " ^ name);
  print_endline ("quantize: " ^ name ^ " passed")

(* ---- the quantizer on its own ---- *)

let test_on_grid_input_is_unchanged () =
  let events = [ (0.0, 1.0); (1.0, 1.5); (1.5, 2.0); (2.25, 4.0) ] in
  check "input already on the grid is left unchanged"
    (quantized settings events
    = [ (q 0 1, q 1 1); (q 1 1, q 1 2); (q 3 2, q 1 2); (q 9 4, q 7 4) ]);
  check "input already on the grid gets no tuplets"
    (tree settings events |> List.for_all (fun t -> not (String.contains t ':')))

let test_jittered_sixteenths () =
  let jitter = [| 0.02; -0.015; 0.01; -0.02; 0.015; -0.01; 0.02; -0.02 |] in
  let events =
    List.init 8 (fun k ->
        let t = (float_of_int k /. 4.0) +. jitter.(k) in
        (t, t +. 0.25))
  in
  check "slightly early/late sixteenths snap back onto sixteenths"
    (quantized settings events |> List.map fst = List.init 8 (fun k -> q k 4))

let test_triplets () =
  let events = [ (0.01, 0.34); (0.34, 0.65); (0.65, 1.0) ] in
  check "near-triplet onsets snap to exact triplets"
    (quantized settings events |> List.map fst = [ q 0 1; q 1 3; q 2 3 ]);
  (* measure -> halves -> beats; beat 1 is a triplet, the rest untouched *)
  check "the first beat is notated as a triplet"
    (tree settings events = [ "((3:(_ _ _) _) _)" ])

let test_quintuplets_and_disabling_tuplets () =
  let events = List.init 5 (fun k -> (float_of_int k /. 5.0, float_of_int (k + 1) /. 5.0)) in
  check "exact quintuplets are kept as quintuplets"
    (quantized settings events |> List.map fst = List.init 5 (fun k -> q k 5));
  check "the beat is notated as a quintuplet"
    (tree settings events = [ "((5:(_ _ _ _ _) _) _)" ]);
  check "with tuplets disabled, quintuplets fall onto the nearest sixteenths"
    (quantized no_tuplets events |> List.map fst
    = [ q 0 1; q 1 4; q 1 2; q 1 2; q 3 4 ])

let test_choosing_tuplets () =
  let near_triplets = [ (0.01, 0.34); (0.34, 0.65); (0.65, 1.0) ] in
  let only_fives = { settings with tuplets = [ 5 ] } in
  check "with only 5 allowed, near-triplets are not made into triplets"
    (tree only_fives near_triplets
    |> List.for_all (fun t -> not (String.contains t '3')));
  check "with only 5 allowed, exact quintuplets still are quintuplets"
    (tree only_fives
       (List.init 5 (fun k -> (float_of_int k /. 5.0, float_of_int (k + 1) /. 5.0)))
    = [ "((5:(_ _ _ _ _) _) _)" ]);
  let rejected tuplets =
    match quantize { settings with tuplets } [ 0.0; 1.0 ] with
    | _ -> false
    | exception Invalid_argument _ -> true
  in
  check "an even or too small tuplet is rejected"
    (rejected [ 4 ] && rejected [ 1 ] && rejected [ 3; 6 ])

let test_simplest_division_wins () =
  check "a whole-measure note leaves the measure undivided"
    (tree settings [ (0.0, 4.0) ] = [ "_" ]);
  (* halves already fit exactly, so no tuplet can be strictly better *)
  check "an off-beat eighth uses plain halves, not a tuplet"
    (tree settings [ (0.5, 1.0) ] = [ "(((_ _) _) _)" ])

let test_ties_and_zero_length () =
  (* The second note puts sixteenths on the grid; the first then sits
     exactly halfway between two of them: starts go earlier, ends later.
     (Alone, it wouldn't: halving doesn't bring 0.125 any closer, so the
     sixteenths never enter the grid.) *)
  check "a start on a tie goes earlier, an end on a tie goes later"
    (quantized no_tuplets [ (0.125, 0.625); (0.25, 0.75) ]
    = [ (q 0 1, q 3 4); (q 1 4, q 1 2) ]);
  check "splitting that brings no point closer does not happen"
    (tree no_tuplets [ (0.125, 0.625) ] = [ "(((_ _) _) _)" ]);
  check "a note that would shrink to nothing becomes one sixteenth"
    (quantized settings [ (1.0, 1.02) ] = [ (q 1 1, q 1 4) ])

let test_other_meters () =
  let three = { settings with beats_per_measure = 3 } in
  check "3/4 divides into its three beats"
    (tree three [ (0.0, 1.0); (1.0, 2.0); (2.0, 3.0) ] = [ "(_ _ _)" ]);
  let five = { settings with beats_per_measure = 5 } in
  let _, r = quantize_events five [ (0.0, 3.0); (3.0, 5.0) ] in
  check "5/4 splits 3+2"
    (match r.measures with
    | [ { division = Plain [ a; b ]; _ } ] ->
        Q.compare a.length (q 3 1) = 0 && Q.compare b.length (q 2 1) = 0
    | _ -> false);
  let _, r = quantize_events settings [ (0.0, 1.0); (5.0, 6.5) ] in
  check "a second measure starts at beat 4"
    (List.map (fun m -> Q.to_string m.start) r.measures = [ "0"; "4" ])

(* ---- applied to a generated score ---- *)

(* One layer with REST switched on (fixed offset), so rest entries are
   covered too. Entry delays 0.1-0.2 s, durations and rests 0.05 s. *)
let formula_sexp =
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
      (durations 0.01 1.0)))
  (instrument-table (0))
  (entrydelays (0.1 0.15 0.2))
  (entrydelay-table (0 1 2))
  (durations (0.05))
  (duration-table (0))
  (registers ((pitch-range percussion)))
  (register-table (0))
  (rest-mode (before-sound-entry 2.0 2.0))
  (rests (0.05))
  (rest-table (0))
  (harmony (principle row) (row (p)) (transposition none))
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

let generated_layer () =
  let sf =
    match Pr26.Sexp.of_string formula_sexp with
    | Error e -> failwith ("quantize_test formula failed to parse: " ^ e)
    | Ok sexps -> (
        match Pr26.Structure_formula.Parse.of_sexp sexps with
        | Error _ -> failwith "quantize_test formula failed to build"
        | Ok (sf, _) -> sf)
  in
  match build_score sf with [ [ layer ] ] -> layer | _ -> assert false

let quantize_at bpm layer =
  Pr26.Score_quantize.quantize_layer { bpm; quantize = settings } layer

let close a b = Float.abs (a -. b) < 1e-9
let dur (Duration d) = d

let test_score_already_on_grid_is_unchanged () =
  let layer = generated_layer () in
  (* at 600 bpm a beat is 0.1 s: every value in this formula is a whole
     number of eighths, so quantizing must not move anything *)
  let quantized = quantize_at 600.0 layer in
  check "a score already on the grid comes back unchanged"
    (List.length quantized = List.length layer
    && List.for_all2
         (fun (a : entry) (b : entry) ->
           close a.time b.time
           && close a.entrydelay b.entrydelay
           && List.length a.notes = List.length b.notes
           && List.for_all2
                (fun (m : note) (n : note) ->
                  close m.time n.time && close (dur m.duration) (dur n.duration))
                a.notes b.notes)
         layer quantized)

let test_score_off_grid_lands_on_grid () =
  let layer = generated_layer () in
  check "the test score contains rests" (List.exists (fun (e : entry) -> e.is_rest) layer);
  let bpm = 437.0 in
  let quantized = quantize_at bpm layer in
  let beats t = t *. bpm /. 60.0 in
  (* every grid point is a multiple of 1/840 beat (sixteenths, triplets,
     quintuplets, septuplets and their halves all divide 840) *)
  let on_grid t =
    let x = beats t *. 840.0 in
    Float.abs (x -. Float.round x) < 1e-6
  in
  check "entry count and note counts are preserved"
    (List.length quantized = List.length layer
    && List.for_all2
         (fun (a : entry) (b : entry) -> List.length a.notes = List.length b.notes)
         layer quantized);
  check "every entry time, entry delay and note end lies on the grid"
    (List.for_all
       (fun (e : entry) ->
         on_grid e.time
         && on_grid (e.time +. e.entrydelay)
         && List.for_all (fun (n : note) -> on_grid (n.time +. dur n.duration)) e.notes)
       quantized);
  check "notes start at their entry and never have zero length"
    (List.for_all
       (fun (e : entry) ->
         List.for_all (fun (n : note) -> n.time = e.time && dur n.duration > 0.0) e.notes)
       quantized);
  check "a rest's duration equals its entry delay"
    (List.for_all
       (fun (e : entry) -> (not e.is_rest) || e.duration = Some (Duration e.entrydelay))
       quantized);
  (* where an entry delay led exactly to the next entry before, it still does *)
  let rec pairs = function a :: (b :: _ as rest) -> (a, b) :: pairs rest | _ -> [] in
  check "entries that were back to back stay back to back"
    (List.for_all2
       (fun ((a : entry), (b : entry)) ((qa : entry), (qb : entry)) ->
         (not (close (a.time +. a.entrydelay) b.time))
         || close (qa.time +. qa.entrydelay) qb.time)
       (pairs layer) (pairs quantized))

(* ---- MIDI carries the quantizing tempo and metre ---- *)

let contains s sub =
  let n = String.length s and m = String.length sub in
  let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
  go 0

let test_midi_tempo_and_meter () =
  let layer = quantize_at 90.0 (generated_layer ()) in
  let file = Filename.temp_file "quantize_test" ".mid" in
  Pr26.Midi_export.write_layer_midi
    ~tempo:{ bpm = 90.0; beats_per_measure = 3; beat_unit = 4 }
    ~tr:12 file layer;
  let ic = open_in_bin file in
  let bytes = really_input_string ic (in_channel_length ic) in
  close_in ic;
  Sys.remove file;
  (* 90 bpm = 666667 us per quarter = 0x0A2C2B; 3/4 = 3, 2^2 *)
  check "MIDI file carries the tempo" (contains bytes "\xFF\x51\x03\x0A\x2C\x2B");
  check "MIDI file carries the time signature" (contains bytes "\xFF\x58\x04\x03\x02")

let () =
  test_on_grid_input_is_unchanged ();
  test_jittered_sixteenths ();
  test_triplets ();
  test_quintuplets_and_disabling_tuplets ();
  test_choosing_tuplets ();
  test_simplest_division_wins ();
  test_ties_and_zero_length ();
  test_other_meters ();
  test_score_already_on_grid_is_unchanged ();
  test_score_off_grid_lands_on_grid ();
  test_midi_tempo_and_meter ()
