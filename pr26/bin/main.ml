
(* note the "list" in pr2 is mostly used as an indexed array *)
type ptable =
  Table of int Array.t Array.t

let of_nested_list lstlst = 
  lstlst |> List.map Array.of_list |> Array.of_list
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

(* test materialas *)

  (* define instruments *)
let violin = inst "violin" (chordsize 1 2)

let piano = inst "piano" (chordsize 1 10)

let basedrum = inst "basedrum" (chordsize 1 1)

(* note: the list from list-table-ensemble in PR2 is actually array
, as we want to index them using ints *)
let instruments_array = [| violin; piano; basedrum |]

let instr_table = Table [
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

type selection_principle =
  | Alea
  | Series
  | Ratio of int list
  | Group of { size : int ; reps : int }
  | Tendency of tendency_section list


let apply_operator ensemble selection_principle =


let alea ensemble = 
  let n = Array.size ensemble in
  ensemble.(Random.int n)

let entry_delay_list = [ 0.1; 0.2; 0.3; 0.4; 0.8 ; 1.2] |> Array.of_list 

let entry_delay_table = 


