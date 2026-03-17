type index = 
  Idx of int

type 'a plist  = 
  string Array.t

(* note the "list" in pr2 is mostly used as an indexed array *)

type 'a ptable =
  Table ((index a) Array.t Array.t)

  


type instrument = 
  Instrument of (plist * ptable)


type