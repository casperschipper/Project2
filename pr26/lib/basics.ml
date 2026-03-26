open Tools

(* as we are indexing the table groups, we use arrays *)
type ptable =
  Table of int Array.t Array.t

let of_nested_list lstlst = 
  lstlst |> List.map Array.of_list |> Array.of_list |>  fun x -> Table x

  (* 
type parameter =
  | Instrument
  | Entrydelay *)
  

type chordsize =
  Chordsize of { minsize : int ; maxsize : int }


(* chordsize is min and max *)
let chordsize mini maxi = 
  Chordsize { minsize = min mini maxi; maxsize = max mini maxi}

(* a table is an array of arrays *)

type instrument = 
  Instrument of { name : string ; chordsize : chordsize }

let inst name chordsize = 
  Instrument { name = name; chordsize = chordsize }

(* test materials *)

  (* define instruments *)
let violin = inst "violin" (chordsize 1 2)

let piano = inst "piano" (chordsize 1 10)

let basedrum = inst "basedrum" (chordsize 1 1)

(* note: the list from list-table-ensemble in PR2 is actually array
, as we want to index them using ints *)
let instruments_array = [| violin; piano; basedrum |]

let instr_table = of_nested_list [
  [0;1;2];
  [0;1];
  [0;3];
  [0];
] 

type tendency_section = 
  TendencySection of { t1 : int 
  ; t2 : int
  ; min1: int
  ; max1 : int
  ; min2 : int
  ; max2 : int 
  }

type group_selection =
  | GroupAlea
  | GroupSeries

type group_spec =
  GroupSpec of { element :group_selection ;repetition : group_selection; min_rep : int ; max_rep : int }

type selection_principle =
  | Alea
  | Series
  | Ratio of int list
  | Group of group_spec
  | Tendency of tendency_section list

let mkGroup elm rep min_rep max_rep = 
  let mi = min min_rep max_rep in
  let ma = max min_rep max_rep in
  GroupSpec { element = elm ; repetition = rep ; min_rep = mi ; max_rep = ma }


let alea_sq ensemble = 
  let n = Array.length ensemble in
  let f () = Some (ensemble.(Random.int n), ()) in
  Seq.unfold f ()

let series_select start = 
  let shuffled () = shuffle start |> Array.to_list in
  let f remain =
    match remain with
    | [] -> (match shuffled () with 
      | x::xs -> Some (x,xs)
      | [] -> None)
    | x::xs -> Some (x, xs)
  in
  Seq.unfold f (shuffled ())

let series_sq n = 
  let start = List.init n id |> Array.of_list in
  series_select start

let rec repeat x n =
  if n <= 0 then
    [] 
  else x :: (repeat x (n-1))

let rec range a b =
  if a > b then []
  else a :: range (a + 1) b

let choose lst = 
  let arr = lst |> Array.of_list in
  let n = Array.length arr in
  Seq.repeat () |> Seq.map (fun () ->  (arr.(Random.int n)))

let  ch_series lst = 
  let arr = lst |> Array.of_list in
  let n = Array.length arr in
  series_sq n |> Seq.map (fun i -> arr.(i))


let ratio_sq lst =
  let start = lst |> List.concat_map (fun (x,n) -> repeat x n) |> Array.of_list in
  series_select start

let random_value a b = 
  let range = abs (b - a) in
  let mini = min a b in 
  mini + Random.int range 

let repeat_n elm n = 
  Seq.repeat elm |> Seq.take n  

let group_sq ensemble (GroupSpec { element  ;repetition ; min_rep  ; max_rep  }) = 
  match (element, repetition) with
  | (GroupAlea, GroupAlea) -> 
    choose ensemble |> Seq.concat_map (fun elm -> repeat_n elm (random_value min_rep max_rep))
  | (GroupSeries, GroupAlea) -> 
    ch_series ensemble |> Seq.concat_map (fun elm -> repeat_n elm (random_value min_rep max_rep))
  | (GroupSeries, GroupSeries) -> 
    (let elms = ch_series ensemble in
    let reps = ch_series (range min_rep max_rep) in
    Seq.map2 repeat_n elms reps |> Seq.concat )
  | (GroupAlea, GroupSeries) -> 
    (let elms = choose ensemble in
    let reps = ch_series (range min_rep max_rep) in
    Seq.map2 repeat_n elms reps |> Seq.concat)





(* let entry_delay_list = [ 0.1; 0.2; 0.3; 0.4; 0.8 ; 1.2] |> Array.of_list 

let entry_delay_table = 
 *)

