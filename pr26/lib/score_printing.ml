(* Renders a generated score ([entry list list], from
   [Score_generation.build_score]) as human-readable text - a flat
   note-per-row view ([write_notes_score]), a hierarchical entry-then-notes
   view ([write_entries_score]), and a stdout dump for quick inspection
   ([print_layers]). Consumes only the final, fully-resolved [entry]/[note]
   values - nothing here touches [proto], [continuing_state], or any part
   of how those values were arrived at, so this module depends on
   [Score_generation], never the other way around. *)

open Parameters
open Score_generation

let build_constraint_map instrs =
  List.map
    (fun (Instrument { instrument; performance; dynamics; durations; _ }) ->
      (instrument, (performance, dynamics, durations)))
    instrs

(* Describe what, if anything, is wrong with a note's performance/dynamic/
   duration given the instrument's allowed modes and duration range. Empty
   list means the note is fine. *)
let instrument_repeated_problem (note : note) =
  if note.diagnostics.instrument_repeated then
    [
      "instrument reused within this chord (not enough distinct instruments to \
       reach the vertical density)";
    ]
  else []

let note_problems constraint_map (note : note) =
  instrument_repeated_problem note
  @
  match List.assoc_opt note.instrument constraint_map with
  | None -> [ "unknown instrument" ]
  | Some (valid_perfs, valid_dyns, valid_durs) ->
      let perf_problem =
        if Performance_modes.mem note.performance valid_perfs then []
        else
          let valid_perfs_str =
            Performance_modes.elements valid_perfs
            |> List.map Performance.to_string
            |> String.concat ", "
          in
          [
            Printf.sprintf "performance '%s' (valid: %s)"
              (Performance.to_string note.performance)
              valid_perfs_str;
          ]
      in
      let dyn_problem =
        if Dynamic_modes.mem note.dynamic valid_dyns then []
        else
          let valid_dyns_str =
            Dynamic_modes.elements valid_dyns
            |> List.map Dynamic.to_string |> String.concat ", "
          in
          [
            Printf.sprintf "dynamic '%s' (valid: %s)"
              (Dynamic.to_string note.dynamic)
              valid_dyns_str;
          ]
      in
      let dur_problem =
        let (Duration d) = note.duration in
        if duration_range_ok valid_durs note.duration then []
        else
          let (AllowedDurations { min; max }) = valid_durs in
          [ Printf.sprintf "duration %.3f (valid: %.3f-%.3f)" d min max ]
      in
      let dur_relation_problem =
        if note.diagnostics.duration_ok then []
        else
          let (Duration d) = note.duration in
          [
            Printf.sprintf
              "duration %.3f could not satisfy the entry-delay relation (no \
               valid candidate existed)"
              d;
          ]
      in
      let pitch_problem =
        if note.diagnostics.pitch_ok then []
        else
          [
            Printf.sprintf "pitch %s did not agree between register and harmony"
              (pitch_to_string note.pitch);
          ]
      in
      let interval_matrix_problem =
        if note.diagnostics.harmony_matrix_ok then []
        else [ "INTERVAL RESTRICTIONS TOO STRICT" ]
      in
      perf_problem @ dyn_problem @ dur_problem @ dur_relation_problem
      @ pitch_problem @ interval_matrix_problem

(* Aligns rows of already-stringified cells by padding each column to its
   widest value. Knows nothing about score events, so it can't drift out of
   sync with whatever ends up being printed. *)
module Table = struct
  let column_widths = function
    | [] -> []
    | row :: _ as rows ->
        let init = List.map (fun _ -> 0) row in
        List.fold_left
          (List.map2 (fun w cell -> max w (String.length cell)))
          init rows

  let render_row widths row =
    List.map2
      (fun w cell -> cell ^ String.make (max 0 (w - String.length cell)) ' ')
      widths row
    |> String.concat " "
end

(* [entrydelay] comes from the note's owning [entry] - a note itself doesn't
   carry one (see [note]'s definition). *)
let note_cells ~entrydelay (note : note) =
  let (InstrumentName name) = note.instrument in
  let (Duration d) = note.duration in
  [
    Debug_log.note_id_to_string note.id;
    Printf.sprintf "%.3f" note.time;
    Printf.sprintf "%.3f" entrydelay;
    Printf.sprintf "%.3f" d;
    name;
    Performance.to_string note.performance;
    Dynamic.to_string note.dynamic;
    pitch_to_string note.pitch;
  ]

let note_header =
  [
    "id";
    "time";
    "entrydelay";
    "duration";
    "instrument";
    "performance";
    "dynamic";
    "pitch";
  ]

(* Flat view: one row per note (a multi-note chord produces several rows
   sharing the same time), ignoring entry grouping entirely. *)
let opt_to_string to_string = function Some v -> to_string v | None -> "-"
let instrument_name_opt = opt_to_string (fun (InstrumentName n) -> n)

(* A REST (EMR-3 7.4) has no notes at all - shown as its own row (7 columns,
   matching [note_cells]'s shape so column alignment stays correct) rather
   than simply vanishing from the score. *)
let rest_cells ~entrydelay (e : entry) =
  let dur_str =
    match e.duration with
    | Some (Duration d) -> Printf.sprintf "%.3f" d
    | None -> "-"
  in
  [
    Debug_log.entry_id_to_string e.id;
    Printf.sprintf "%.3f" e.time;
    Printf.sprintf "%.3f" entrydelay;
    dur_str;
    "REST";
    "-";
    "-";
    "-";
  ]

let cells_for_entry_notes (e : entry) =
  if e.is_rest then [ rest_cells ~entrydelay:e.entrydelay e ]
  else
    List.map (fun (n : note) -> note_cells ~entrydelay:e.entrydelay n) e.notes

let write_notes_score filename instrs (layers : entry list list) =
  let constraint_map = build_constraint_map instrs in
  let all_rows =
    note_header
    :: (layers |> List.concat_map (List.concat_map cells_for_entry_notes))
  in
  let widths = Table.column_widths all_rows in
  let oc = open_out filename in
  List.iteri
    (fun i (entries : entry list) ->
      Printf.fprintf oc "# layer %d\n" i;
      entries
      |> List.iter (fun (e : entry) ->
          if e.is_rest then
            Printf.fprintf oc "%s\n"
              (Table.render_row widths (rest_cells ~entrydelay:e.entrydelay e))
          else
            e.notes
            |> List.iter (fun note ->
                Printf.fprintf oc "%s"
                  (Table.render_row widths
                     (note_cells ~entrydelay:e.entrydelay note));
                (match note_problems constraint_map note with
                | [] -> ()
                | problems ->
                    Printf.fprintf oc " # IMPOSSIBLE: %s"
                      (String.concat ", " problems));
                Printf.fprintf oc "\n")))
    layers;
  close_out oc

(* The autonomous-density target sampled for [e] - always exactly the number
   of notes it ended up with, since [resolve_layer_autonomous]'s [fill_group]
   fills each chord to precisely that count. Shown as "-" under
   [InstrumentDensity], where note count is just the picked instrument's own
   chordsize, not a density the composer's algorithm chose. *)
let density_cell density (e : entry) =
  match density with
  | Autonomous _ -> string_of_int (List.length e.notes)
  | InstrumentDensity -> "-"
  | ChordDensity -> string_of_int (List.length e.notes)

let density_header_comment = function
  | Autonomous { low; high; _ } ->
      Printf.sprintf "# density: autonomous (low %d, high %d)\n" low high
  | InstrumentDensity -> "# density: instrument\n"
  | ChordDensity -> "# density: chord\n"

(* Hierarchical view: one header line per entry (time, instrument, note
   count, and whichever of performance/dynamic/duration were chord-wide),
   followed by its notes indented underneath. [instrument] is "-" when an
   entry's notes span more than one instrument (EMR-3 8.16 "scoring"). *)
let write_entries_score filename instrs ~density (layers : entry list list) =
  let constraint_map = build_constraint_map instrs in
  let entry_cells (e : entry) =
    [
      Debug_log.entry_id_to_string e.id;
      Printf.sprintf "%.3f" e.time;
      Printf.sprintf "%.3f" e.entrydelay;
      opt_to_string (fun (Duration d) -> Printf.sprintf "%.3f" d) e.duration;
      (if e.is_rest then "REST" else instrument_name_opt e.instrument);
      string_of_int (List.length e.notes);
      density_cell density e;
      opt_to_string Performance.to_string e.performance;
      opt_to_string Dynamic.to_string e.dynamic;
      opt_to_string pitch_to_string e.pitch;
    ]
  in
  let entry_header =
    [
      "id";
      "time";
      "entrydelay";
      "duration";
      "instrument";
      "notes";
      "density";
      "performance";
      "dynamic";
      "pitch";
    ]
  in
  let all_entry_rows =
    entry_header :: (layers |> List.concat_map (List.map entry_cells))
  in
  let entry_widths = Table.column_widths all_entry_rows in
  let all_note_rows =
    note_header
    :: (layers |> List.concat_map (List.concat_map cells_for_entry_notes))
  in
  let note_widths = Table.column_widths all_note_rows in
  let oc = open_out filename in
  Printf.fprintf oc "%s" (density_header_comment density);
  List.iteri
    (fun i (entries : entry list) ->
      Printf.fprintf oc "# layer %d\n" i;
      entries
      |> List.iter (fun (e : entry) ->
          Printf.fprintf oc "%s\n"
            (Table.render_row entry_widths (entry_cells e));
          if e.is_rest then
            Printf.fprintf oc "    %s\n"
              (Table.render_row note_widths
                 (rest_cells ~entrydelay:e.entrydelay e))
          else
            e.notes
            |> List.iter (fun note ->
                Printf.fprintf oc "    %s"
                  (Table.render_row note_widths
                     (note_cells ~entrydelay:e.entrydelay note));
                (match note_problems constraint_map note with
                | [] -> ()
                | problems ->
                    Printf.fprintf oc " # IMPOSSIBLE: %s"
                      (String.concat ", " problems));
                Printf.fprintf oc "\n")))
    layers;
  close_out oc

let print_layers instrs (layers : entry list list) =
  let constraint_map = build_constraint_map instrs in
  let total_violations = ref 0 in
  print_endline "\n=== instrument_entry_test ===";
  List.iteri
    (fun i (entries : entry list) ->
      Printf.printf "\n--- layer %d ---\n" i;
      Printf.printf "%-14s %-8s %-10s %-8s %-14s %-5s %-12s %-8s %s\n" "id"
        "time" "entrydelay" "duration" "instrument" "notes" "performance"
        "dynamic" "status";
      entries
      |> List.iter (fun (e : entry) ->
          e.notes
          |> List.iter (fun (note : note) ->
              let problems = note_problems constraint_map note in
              let status =
                match problems with
                | [] -> ""
                | ps ->
                    incr total_violations;
                    "!! IMPOSSIBLE: " ^ String.concat ", " ps
              in
              let (Duration d) = note.duration in
              let (InstrumentName name) = note.instrument in
              Printf.printf
                "%-14s %-8.3f %-10.3f %-8.3f %-14s %-5d %-12s %-8s %s\n"
                (Debug_log.note_id_to_string note.id)
                note.time e.entrydelay d name (List.length e.notes)
                (Performance.to_string note.performance)
                (Dynamic.to_string note.dynamic)
                status)))
    layers;
  print_endline "";
  if !total_violations = 0 then
    print_endline
      "OK: every performance, dynamic, duration and pitch is valid for its \
       instrument"
  else
    Printf.printf
      "VIOLATIONS: %d note(s) have invalid performance/dynamic/duration/pitch\n"
      !total_violations
