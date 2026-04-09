type byte = int
type message = byte * byte * byte
type stream = message Seq.t

val byte : int -> int

val note_on :
channel:int -> note:int -> velocity:int -> int * int * int

val note_off :
channel:int -> note:int -> velocity:int -> int * int * int

val control_change :
channel:int ->
controller:int ->
value:int ->
int * int * int

val of_list : 'a list -> 'a Seq.t
val to_list : 'a Seq.t -> 'a list


