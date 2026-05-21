module UnitFloat : sig
  type t = private float

  val make : float -> t option
  val of_float_exn : float -> t
end = struct
  type t = float

  let make x = if x >= 0.0 && x <= 1.0 then Some x else None

  let of_float_exn x =
    if x >= 0.0 && x <= 1.0 then x
    else raise (Invalid_argument (Printf.sprintf "UnitFloat.of_float_exn: %f is not in [0,1]" x))
end

let singleton_array x = [| x |]
let tuple_map f (x, y) = (f x, f y)
let tuple_reduce f (x, y) = f x y

let shuffle arr =
  let arr = Array.copy arr in
  let n = Array.length arr in
  for i = n - 1 downto 1 do
    let j = Random.int (i + 1) in
    let temp = arr.(i) in
    arr.(i) <- arr.(j);
    arr.(j) <- temp
  done;
  arr

let id x = x
let print_int_list label lst = Printf.printf "%s:\n [%s]\n" label (lst |> List.map string_of_int |> String.concat "; ")
let lerp a b t = a +. (t *. (b -. a))
let repeat x n = List.init n (fun _ -> x)
let range a b = if a > b then [] else List.init (b - a) (fun x -> x + a)

(* 
  Here we sample a list, allowing repetition
*)
let choose lst =
  let arr = lst |> Array.of_list in
  let n = Array.length arr in
  Seq.repeat () |> Seq.map (fun () -> arr.(Random.int n))

(* choose, but only return one value *)
let choose_arr arr = arr.(Random.int (Array.length arr))

(* return one value *)
let choose_lst lst = choose_arr (Array.of_list lst)

(* A seq.t of length n, just repeating the value *)
let repeat_n elm n = Seq.repeat elm |> Seq.take n

let debug_float label x =
  print_string ("\n" ^ label);
  print_float x;
  flush stdout

let print_float_list label lst =
  Printf.printf "%s:\n [%s]\n" label (lst |> List.map (Printf.sprintf "%.3f") |> String.concat "; ")

let bangs count = Seq.repeat () |> Seq.take count
let lookup_arr arr i = arr.(i)

let rec chunk chunkSize sq () =
  let open Seq in
  match chunkSize () with
  | Nil -> Nil
  | Cons (n, ntl) ->
      let current_chunk = take n sq in
      let sqTail = drop n sq in
      Cons (current_chunk, chunk ntl sqTail)

module Validated = struct
  type ('a, 'e) t = ('a, 'e list) result

  let pure x = Ok x

  let ( <*> ) f x =
    match (f, x) with
    | Ok f, Ok x -> Ok (f x)
    | Error e, Ok _ -> Error e
    | Ok _, Error e -> Error e
    | Error e1, Error e2 -> Error (e1 @ e2)

  let of_result r = Result.map_error List.singleton r

  (* f <$> x : start a chain — plain function applied to first result arg *)
  let ( <$> ) f x = of_result (Result.map f x)

  (* f <+> x : continue a chain — auto-lifts a plain result on the right *)
  let ( <+> ) f x = f <*> of_result x
  let sequence lst = List.fold_right (fun r acc -> pure List.cons <*> r <*> acc) lst (pure [])
end

let sequence_result arr =
  List.fold_right
    (fun r acc -> match (r, acc) with Ok x, Ok xs -> Ok (x :: xs) | Error e, _ | _, Error e -> Error e)
    arr (Ok [])

let print_header str =
  print_endline str;
  print_endline (List.init (String.length str) (fun _ -> "=") |> String.concat "");
  print_newline ()
