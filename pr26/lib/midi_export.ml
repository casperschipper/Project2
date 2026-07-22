(* Exports a generated score straight from Score_generation's [entry]/[note]
   values to one Standard MIDI File per layer - no text round-trip through
   score.projekt2, so this can never drift out of sync with the writer for
   that file. Pure Stdlib, no external dependencies.

   Each note's own resolved [pitch] (REGISTER + HARMONY, see
   [Parameters.resolve_pitch]) becomes its MIDI note number; [Percussion]
   notes are pinned to one fixed note. *)

open Parameters

(* Fixed "no pitch" MIDI note for [Percussion] notes - an arbitrary but
   recognizable choice (GM 42 = closed hi-hat), not a full GM drum-kit
   mapping. *)
let percussion_midi_note = 42

(* [tr] (tones per octave) is composer-set and may not be 12, so this is
   necessarily lossy for a fixed-pitch format like MIDI: each relative
   pitch (1..tr) is scaled to the nearest 12-tone-equal-tempered semitone. *)
let midi_note_of_pitch ~tr = function
  | Percussion -> percussion_midi_note
  | Pitched { octave = Octave o; step = Step s } ->
      let semitone =
        int_of_float (Float.round (float_of_int (s - 1) *. 12.0 /. float_of_int tr))
      in
      max 0 (min 127 ((12 * o) + semitone))

let ticks_per_quarter = 480
let microseconds_per_quarter = 500_000 (* fixed 120bpm - the score has no tempo of its own *)

let ticks_per_second =
  float_of_int ticks_per_quarter
  /. (float_of_int microseconds_per_quarter /. 1_000_000.0)

let tick_of_seconds s = int_of_float (Float.round (s *. ticks_per_second))

let velocity_of_dynamic (d : Dynamic.t) =
  match Dynamic.to_string d with
  | "ppp" -> 20
  | "pp" -> 35
  | "p" -> 50
  | "mf" -> 65
  | "f" -> 80
  | "ff" -> 95
  | "fff" -> 110
  | _ -> 80

(* ---- low-level Standard MIDI File writing ---- *)

let add_u16_be buf n =
  Buffer.add_char buf (Char.chr ((n asr 8) land 0xff));
  Buffer.add_char buf (Char.chr (n land 0xff))

let add_u32_be buf n =
  Buffer.add_char buf (Char.chr ((n asr 24) land 0xff));
  Buffer.add_char buf (Char.chr ((n asr 16) land 0xff));
  Buffer.add_char buf (Char.chr ((n asr 8) land 0xff));
  Buffer.add_char buf (Char.chr (n land 0xff))

(* Variable-length quantity, as required for every MIDI delta-time. *)
let add_vlq buf n =
  let rec septets n = if n < 0x80 then [ n ] else septets (n asr 7) @ [ n land 0x7f ] in
  let rec emit = function
    | [] -> ()
    | [ last ] -> Buffer.add_char buf (Char.chr last)
    | s :: rest ->
        Buffer.add_char buf (Char.chr (s lor 0x80));
        emit rest
  in
  emit (septets (max n 0))

let add_meta_track_name buf name =
  add_vlq buf 0;
  Buffer.add_string buf "\xFF\x03";
  add_vlq buf (String.length name);
  Buffer.add_string buf name

let add_meta_end_of_track buf =
  add_vlq buf 0;
  Buffer.add_string buf "\xFF\x2F\x00"

let add_tempo buf =
  add_vlq buf 0;
  Buffer.add_string buf "\xFF\x51\x03";
  Buffer.add_char buf (Char.chr ((microseconds_per_quarter asr 16) land 0xff));
  Buffer.add_char buf (Char.chr ((microseconds_per_quarter asr 8) land 0xff));
  Buffer.add_char buf (Char.chr (microseconds_per_quarter land 0xff))

let track_chunk body =
  let buf = Buffer.create (Buffer.length body + 8) in
  Buffer.add_string buf "MTrk";
  add_u32_be buf (Buffer.length body);
  Buffer.add_buffer buf body;
  buf

let header_chunk ~ntracks =
  let buf = Buffer.create 14 in
  Buffer.add_string buf "MThd";
  add_u32_be buf 6;
  add_u16_be buf 1 (* format 1: one tempo/meta track + N independent tracks *);
  add_u16_be buf ntracks;
  add_u16_be buf ticks_per_quarter;
  buf

let tempo_track () =
  let buf = Buffer.create 16 in
  add_tempo buf;
  add_meta_end_of_track buf;
  track_chunk buf

(* One instrument's notes -> one track, on its own channel. Every note
   becomes a Note On followed by a Note Off at its own resolved pitch; ties
   at the same tick are ordered Off-before-On so a note that reuses the
   previous one's pitch back-to-back doesn't leave a hanging note. *)
let instrument_track ~channel ~tr ~name (notes : Score_generation.note list) =
  let events =
    notes
    |> List.concat_map (fun (n : Score_generation.note) ->
        let (Duration dur) = n.duration in
        let start = tick_of_seconds n.time in
        let stop = max (start + 1) (tick_of_seconds (n.time +. dur)) in
        let pitch = midi_note_of_pitch ~tr n.pitch in
        [
          (start, true, pitch, velocity_of_dynamic n.dynamic);
          (stop, false, pitch, 0);
        ])
    |> List.stable_sort (fun (t1, on1, _, _) (t2, on2, _, _) ->
        if t1 <> t2 then compare t1 t2 else compare on1 on2)
  in
  let buf = Buffer.create 256 in
  add_meta_track_name buf name;
  let (_ : int) =
    List.fold_left
      (fun last_tick (tick, on, pitch, velocity) ->
        add_vlq buf (tick - last_tick);
        Buffer.add_char buf (Char.chr ((if on then 0x90 else 0x80) lor (channel land 0x0f)));
        Buffer.add_char buf (Char.chr (pitch land 0x7f));
        Buffer.add_char buf (Char.chr (velocity land 0x7f));
        tick)
      0 events
  in
  add_meta_end_of_track buf;
  track_chunk buf

let distinct_instruments (notes : Score_generation.note list) =
  List.fold_left
    (fun acc (n : Score_generation.note) ->
      if List.mem n.instrument acc then acc else acc @ [ n.instrument ])
    [] notes

(* One layer -> one file: one track per instrument that actually plays in
   this layer, each on its own channel. *)
let write_layer_midi ~tr filename (entries : Score_generation.entry list) =
  let notes = entries |> List.concat_map (fun (e : Score_generation.entry) -> e.notes) in
  let instruments = distinct_instruments notes in
  let tracks =
    instruments
    |> List.mapi (fun i instr ->
        let (InstrumentName name) = instr in
        let channel = i mod 16 in
        let notes_for_instr = notes |> List.filter (fun (n : Score_generation.note) -> n.instrument = instr) in
        instrument_track ~channel ~tr ~name notes_for_instr)
  in
  let oc = open_out_bin filename in
  Buffer.output_buffer oc (header_chunk ~ntracks:(1 + List.length tracks));
  Buffer.output_buffer oc (tempo_track ());
  List.iter (Buffer.output_buffer oc) tracks;
  close_out oc

(* Each layer becomes its own file ([prefix]_layer0.mid, [prefix]_layer1.mid,
   ...) so they can be imported into a DAW as separate parts. *)
let write_layers_midi ~prefix ~tr (layers : Score_generation.entry list list) =
  layers
  |> List.iteri (fun i entries ->
      write_layer_midi ~tr (Printf.sprintf "%s_layer%d.mid" prefix i) entries)
