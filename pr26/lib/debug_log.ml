(* Opt-in, machine-readable record of *why* a value was picked during score
   generation - which selection principle fired, whether a SERIES/RATIO cycle
   restarted, when a GROUP started a new repetition, what restricted a
   choice, the current TENDENCY window, and whether a parameter's generator
   state continued across a layer/variant boundary. Intended as input to a
   future visualisation tool, not for a person to read directly (see
   "manuals and notes/debug_output.md").

   A mutable side-channel, deliberately, rather than an accumulator threaded
   through every fold's return value - the same category of orthogonal
   diagnostic stream [Main_sexp]'s [capture_stdout] already uses for the
   human-readable log. This module knows nothing about [Score_generation]'s
   own types (no [note]/[proto]/[sel_state]) so it can stay a dependency
   leaf - [Score_generation] depends on it, never the other way around. *)

(* A REST (EMR-3 7.4) is spliced in by a separate pass, after every
   "resolved" entry already has a permanent, final [Resolved n] id - so a
   rest never needs to borrow or shift a resolved entry's number. It is
   instead identified by which resolved entry it was placed immediately
   before, which is already unique per layer (see
   [Score_generation.rest_insertion]'s [before_index]: strictly increasing,
   never repeated). *)
type entry_seq = Resolved of int | RestBefore of int

type entry_id = { variant : int; layer : int; seq : entry_seq }
type note_id = { of_entry : entry_id; note : int }

(* Bootstrapping value only: [Score_generation.notes_of_proto] builds a
   [note] before its owning [entry]'s id is known (a chord's notes come from
   several concatenated sub-picks, so the note's final within-chord index
   isn't known until they're all joined together). [entry_of_group]
   immediately overwrites this with the real id once that position is known
   - it is never observed anywhere else. *)
let placeholder_note_id : note_id =
  { of_entry = { variant = -1; layer = -1; seq = Resolved (-1) }; note = -1 }

(* Mirrors [Parameters.hierarchy_elem]'s [Ins]/[Per]/[Dyn]/[Dur]/[Reg] for
   the five hierarchy-ordered parameters, plus the non-hierarchy-ordered
   principles that still draw through the same generic [sel_state] machinery
   (entry-delay, REST, the autonomous/chord-density target, CHORD's own
   ordering) and HARMONY (which isn't a generic [sel_state] at all, but still
   restricts and gets restricted by other parameters). *)
type param =
  | PIns
  | PEnt
  | PPer
  | PDyn
  | PDur
  | PReg
  | PHar
  | PRest
  | PDensity
  | PChordOrder

type context = { variant : int; layer : int; seq : entry_seq; param : param }

type event =
  | SeriesRestart of context
  | RatioRefresh of context
  | GroupNewRep of { ctx : context; element : string; size : int }
  | TendencyWindow of { ctx : context; lo : float; hi : float }
  | Restriction of { ctx : context; restricted_by : string list }
  (* Per layer, per parameter - fires once, before that layer's first entry
     is resolved (see [Score_generation.resolve_layer_groups]'s
     [continue_or_restart] calls), not tied to any one entry. *)
  | Continuation of { variant : int; layer : int; param : param; continued : bool }
  | VariantTendencyReset of { variant : int; param : param }

let enabled = ref false
let buffer : event list ref = ref []
let reset () = buffer := []

(* [emit] takes a thunk so the event (and whatever computation builds its
   fields) is never constructed at all when disabled - not merely discarded
   after being built. The same idiom as [Logs.debug (fun m -> m "...")], for
   the same reason. *)
let emit (f : unit -> event) = if !enabled then buffer := f () :: !buffer

(* For call sites that already had to evaluate their condition for other
   reasons (SERIES/RATIO/GROUP detection - see [Score_generation]) and so
   gain nothing from a thunk. *)
let push (e : event) = if !enabled then buffer := e :: !buffer
let events () = List.rev !buffer

let param_to_string = function
  | PIns -> "instrument"
  | PEnt -> "entrydelay"
  | PPer -> "performance"
  | PDyn -> "dynamic"
  | PDur -> "duration"
  | PReg -> "register"
  | PHar -> "harmony"
  | PRest -> "rest"
  | PDensity -> "density"
  | PChordOrder -> "chord-order"

let entry_seq_to_string = function
  | Resolved n -> Printf.sprintf "E%d" n
  | RestBefore n -> Printf.sprintf "R%d" n

let entry_id_to_string (id : entry_id) =
  Printf.sprintf "v%d.L%d.%s" id.variant id.layer (entry_seq_to_string id.seq)

let note_id_to_string (id : note_id) =
  Printf.sprintf "%s.n%d" (entry_id_to_string id.of_entry) id.note

(* ---- JSON ----
   Reuses [Parameters]'s minimal string-based JSON builders rather than
   inventing a second serialisation scheme - there is no JSON library in
   this project's dependencies. *)

let json_of_entry_seq = function
  | Resolved n -> Parameters.json_obj [ ("kind", Parameters.json_string "resolved"); ("n", string_of_int n) ]
  | RestBefore n -> Parameters.json_obj [ ("kind", Parameters.json_string "restBefore"); ("n", string_of_int n) ]

let json_of_context { variant; layer; seq; param } =
  [
    ("variant", string_of_int variant);
    ("layer", string_of_int layer);
    ("entry", json_of_entry_seq seq);
    ("param", Parameters.json_string (param_to_string param));
  ]

let json_of_event = function
  | SeriesRestart ctx ->
      Parameters.json_obj
        (("type", Parameters.json_string "series_restart") :: json_of_context ctx)
  | RatioRefresh ctx ->
      Parameters.json_obj
        (("type", Parameters.json_string "ratio_refresh") :: json_of_context ctx)
  | GroupNewRep { ctx; element; size } ->
      Parameters.json_obj
        (("type", Parameters.json_string "group_new_rep")
        :: ("element", Parameters.json_string element)
        :: ("size", string_of_int size)
        :: json_of_context ctx)
  | TendencyWindow { ctx; lo; hi } ->
      Parameters.json_obj
        (("type", Parameters.json_string "tendency_window")
        :: ("lo", Printf.sprintf "%g" lo)
        :: ("hi", Printf.sprintf "%g" hi)
        :: json_of_context ctx)
  | Restriction { ctx; restricted_by } ->
      Parameters.json_obj
        (("type", Parameters.json_string "restriction")
        :: ( "restrictedBy",
             Parameters.json_array
               (List.map Parameters.json_string restricted_by) )
        :: json_of_context ctx)
  | Continuation { variant; layer; param; continued } ->
      Parameters.json_obj
        [
          ("type", Parameters.json_string "continuation");
          ("variant", string_of_int variant);
          ("layer", string_of_int layer);
          ("param", Parameters.json_string (param_to_string param));
          ("continued", if continued then "true" else "false");
        ]
  | VariantTendencyReset { variant; param } ->
      Parameters.json_obj
        [
          ("type", Parameters.json_string "variant_tendency_reset");
          ("variant", string_of_int variant);
          ("param", Parameters.json_string (param_to_string param));
        ]

let to_json () = Parameters.json_array (List.map json_of_event (events ()))
