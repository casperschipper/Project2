(* Rhythmic quantization with tuplets, after FOMUS (David Psenicka,
   https://github.com/ormf/fomus, quantize.lisp + splitrules.lisp).

   Knows nothing about PR2: it takes time points in beats (floats) and
   returns a grid of notatable positions (exact fractions of a beat) to snap
   them to, plus the division tree that produced the grid - which beat was
   left whole, which was halved, which became a triplet, etc.

   How the grid is chosen, one measure at a time:
   - A segment of time has two candidate grids: "don't divide" (only its two
     end points) and every allowed division of it (halves, beats, tuplets),
     where each part is itself solved recursively the same way.
   - The candidate whose grid lies closest to the input points wins
     (smallest sum of squared distances, each point to its nearest grid
     point).
   - There is no penalty for complexity. Simpler rhythms win only because
     "don't divide" is tried first, plain divisions before tuplets, and a
     later candidate replaces an earlier one only if it is strictly closer.
   - A segment is not divided when no point lies strictly inside it, or when
     its parts would be shorter than 3/4 of [1 / beat_division] beats.

   Simplifications against FOMUS: no nested tuplets (inside a tuplet, parts
   are only halved), and no dotted or syncopated split rules - those give
   the same grid points as plain halving, and only matter for how the
   result is notated, not where notes land. *)

(* Exact rationals, since a triplet eighth (1/3 beat) has no exact float. *)
module Q = struct
  type t = { num : int; den : int } (* den > 0, lowest terms *)

  let rec gcd a b = if b = 0 then abs a else gcd b (a mod b)

  let make num den =
    if den = 0 then invalid_arg "Quantize.Q.make: zero denominator";
    let g = gcd num den in
    let g = if den < 0 then -g else g in
    { num = num / g; den = den / g }

  let of_int n = { num = n; den = 1 }
  let zero = of_int 0
  let add a b = make ((a.num * b.den) + (b.num * a.den)) (a.den * b.den)
  let sub a b = make ((a.num * b.den) - (b.num * a.den)) (a.den * b.den)
  let mul_int a n = make (a.num * n) a.den
  let div_int a n = make a.num (a.den * n)
  let compare a b = compare (a.num * b.den) (b.num * a.den)
  let to_float a = float_of_int a.num /. float_of_int a.den

  let to_string a =
    if a.den = 1 then string_of_int a.num else Printf.sprintf "%d/%d" a.num a.den
end

type settings = {
  beats_per_measure : int;
  (* Finest plain division of one beat: 4 = sixteenths when the beat is a
     quarter. Also bounds how short a tuplet's parts may be. *)
  beat_division : int;
  (* Tuplets that may be used, each an odd number >= 3 (e.g. [3; 5; 7]).
     [] disables tuplets. Even ones need no entry: a sextuplet is a
     triplet halved, which [beat_division] already allows or not. *)
  tuplets : int list;
  (* Shortest/longest span, in beats, a tuplet may cover. *)
  min_tuplet_dur : Q.t;
  max_tuplet_dur : Q.t;
}

let default_settings =
  {
    beats_per_measure = 4;
    beat_division = 4;
    tuplets = [ 3; 5; 7 ];
    min_tuplet_dur = Q.make 1 3;
    max_tuplet_dur = Q.of_int 4;
  }

type division =
  | Whole (* not divided: only its start and end are grid points *)
  | Plain of segment list (* halves, or a measure split into beats *)
  | Tuplet of int * segment list (* n equal parts, n odd *)

and segment = { start : Q.t; length : Q.t; division : division }

type result = {
  measures : segment list;
  grid : Q.t array; (* every grid point, sorted, no duplicates *)
}

(* Compact form for tests and debugging: "_" undivided, "(a b)" plain,
   "3:(a b c)" a triplet. *)
let rec division_to_string = function
  | Whole -> "_"
  | Plain segs -> "(" ^ segments_to_string segs ^ ")"
  | Tuplet (n, segs) -> Printf.sprintf "%d:(%s)" n (segments_to_string segs)

and segments_to_string segs =
  segs |> List.map (fun s -> division_to_string s.division) |> String.concat " "

(* Float slack for "is this point exactly on a boundary". *)
let eps = 1e-9

let is_pow2 n = n > 0 && n land (n - 1) = 0

let smallest_prime_factor n =
  let rec go d = if d * d > n then n else if n mod d = 0 then d else go (d + 1) in
  go 2

type split_kind = SplitPlain | SplitTuplet of int

(* Plain splits of a segment [length] beats long, as lists of part lengths.
   A whole number of beats splits along beats: halves when even, thirds
   when divisible by 3, otherwise every two-part split with a power-of-two
   side (5 -> 3+2, 2+3, 4+1, 1+4). Anything shorter is halved. *)
let plain_splits (length : Q.t) =
  let open Q in
  if length.den = 1 && length.num >= 2 then
    let n = length.num in
    match smallest_prime_factor n with
    | 2 -> [ [ of_int (n / 2); of_int (n / 2) ] ]
    | 3 -> [ List.init 3 (fun _ -> of_int (n / 3)) ]
    | _ ->
        (* Nearest the middle first, the longer part first on a tie
           (3+2 before 2+3), as FOMUS orders them - decides equal-error
           ties. *)
        List.init (n - 1) (fun i -> i + 1)
        |> List.filter (fun k -> is_pow2 k || is_pow2 (n - k))
        |> List.sort (fun a b -> Stdlib.compare (abs ((2 * a) - n), -a) (abs ((2 * b) - n), -b))
        |> List.map (fun k -> [ of_int k; of_int (n - k) ])
  else [ [ div_int length 2; div_int length 2 ] ]

(* Each allowed tuplet over the whole segment, smallest first. Skipped when
   the parts would be a power-of-two fraction of a beat - that is an
   ordinary division, not a tuplet (e.g. "3 over 3 beats" is just three
   beats). *)
let tuplet_splits s ~in_tuplet (length : Q.t) =
  if
    in_tuplet
    || Q.compare length s.min_tuplet_dur < 0
    || Q.compare length s.max_tuplet_dur > 0
  then []
  else
    List.sort_uniq compare s.tuplets
    |> List.filter_map (fun j ->
        let part = Q.div_int length j in
        if is_pow2 part.num && is_pow2 part.den then None
        else Some (SplitTuplet j, List.init j (fun _ -> part)))

let nearest_distance (grid : float list) p =
  List.fold_left (fun acc g -> Float.min acc (Float.abs (g -. p))) infinity grid

let squared_error (grid : Q.t list) points =
  let grid = List.map Q.to_float grid in
  List.fold_left
    (fun acc p ->
      let d = nearest_distance grid p in
      acc +. (d *. d))
    0.0 points

let merge_grids grids = List.sort_uniq Q.compare (List.concat grids)

let points_within ~start ~stop points =
  let fs = Q.to_float start and fe = Q.to_float stop in
  List.filter (fun p -> p >= fs -. eps && p <= fe +. eps) points

(* Best segment tree and grid for [points], all within [start, start +
   length]. *)
let rec best s ~in_tuplet ~start ~length points : segment * Q.t list =
  let stop = Q.add start length in
  let whole = ({ start; length; division = Whole }, [ start; stop ]) in
  let fs = Q.to_float start and fe = Q.to_float stop in
  let any_inside =
    List.exists (fun p -> p > fs +. eps && p < fe -. eps) points
  in
  if not any_inside then whole
  else
    let min_part = Q.make 3 (4 * s.beat_division) in
    let candidates =
      List.map (fun parts -> (SplitPlain, parts)) (plain_splits length)
      @ tuplet_splits s ~in_tuplet length
      |> List.filter (fun (_, parts) ->
          List.for_all (fun p -> Q.compare p min_part >= 0) parts)
    in
    let evaluate (kind, parts) =
      let in_tuplet = in_tuplet || kind <> SplitPlain in
      let _, rev_solved =
        List.fold_left
          (fun (part_start, acc) part ->
            let part_stop = Q.add part_start part in
            let solved =
              best s ~in_tuplet ~start:part_start ~length:part
                (points_within ~start:part_start ~stop:part_stop points)
            in
            (part_stop, solved :: acc))
          (start, []) parts
      in
      let segs, grids = List.split (List.rev rev_solved) in
      let division =
        match kind with SplitPlain -> Plain segs | SplitTuplet j -> Tuplet (j, segs)
      in
      ({ start; length; division }, merge_grids grids)
    in
    let (seg, grid), _ =
      List.fold_left
        (fun ((_, best_err) as best_so_far) candidate ->
          let ((_, grid) as solved) = evaluate candidate in
          let err = squared_error grid points in
          if err < best_err -. 1e-12 then (solved, err) else best_so_far)
        (whole, squared_error (snd whole) points)
        candidates
    in
    (seg, grid)

let quantize s (points : float list) : result =
  if s.beats_per_measure < 1 then invalid_arg "Quantize: beats_per_measure < 1";
  if s.beat_division < 1 then invalid_arg "Quantize: beat_division < 1";
  List.iter
    (fun j ->
      if j < 3 || j mod 2 = 0 then
        invalid_arg (Printf.sprintf "Quantize: tuplet %d is not an odd number >= 3" j))
    s.tuplets;
  List.iter
    (fun p ->
      if Float.is_nan p || p < 0.0 then invalid_arg "Quantize: negative or NaN point")
    points;
  let m = s.beats_per_measure in
  let last = List.fold_left Float.max 0.0 points in
  let n_measures = max 1 (int_of_float (Float.ceil ((last -. eps) /. float_of_int m))) in
  let solved =
    List.init n_measures (fun i ->
        let start = Q.of_int (i * m) and length = Q.of_int m in
        best s ~in_tuplet:false ~start ~length
          (points_within ~start ~stop:(Q.add start length) points))
  in
  let measures, grids = List.split solved in
  { measures; grid = Array.of_list (merge_grids grids) }

(* Nearest grid point to [x]. On an exact tie, starts go to the earlier
   point and ends to the later one (as in FOMUS), so a note never shrinks
   to nothing just because it sat halfway. *)
let nearest ~prefer_later (r : result) x =
  let g = r.grid in
  let n = Array.length g in
  (* first index whose grid point is >= x *)
  let rec search lo hi =
    if lo >= hi then lo
    else
      let mid = (lo + hi) / 2 in
      if Q.to_float g.(mid) < x then search (mid + 1) hi else search lo mid
  in
  let i = search 0 n in
  if i = 0 then g.(0)
  else if i = n then g.(n - 1)
  else
    let before = g.(i - 1) and after = g.(i) in
    let db = x -. Q.to_float before and da = Q.to_float after -. x in
    if da < db || (da = db && prefer_later) then after else before

let snap r x = nearest ~prefer_later:false r x
let snap_end r x = nearest ~prefer_later:true r x

(* A note whose end snaps onto (or before) its start would vanish. FOMUS
   makes it a grace note; there is no such thing here, so it gets the
   shortest plain value instead ([1 / beat_division] beats). *)
let snap_duration s r ~(onset : Q.t) stop =
  let e = snap_end r stop in
  if Q.compare e onset > 0 then Q.sub e onset else Q.make 1 s.beat_division

(* Convenience for a flat list of (onset, end) pairs in beats: returns
   (onset, duration) in beats, plus the grid/tree used. *)
let quantize_events s (events : (float * float) list) =
  let points = List.concat_map (fun (a, b) -> [ a; b ]) events in
  let r = quantize s points in
  let quantized =
    List.map
      (fun (a, b) ->
        let onset = snap r a in
        (onset, snap_duration s r ~onset b))
      events
  in
  (quantized, r)
