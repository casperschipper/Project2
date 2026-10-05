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

(* The score itself has no tempo, so by default the files are written at a
   fixed 120bpm with no time signature. A quantized score ([Score_quantize])
   passes its own tempo and metre instead, so its beats land on the MIDI
   file's beats. [bpm] counts beats of [beat_unit] (4 = quarter). *)
type tempo = { bpm : float; beats_per_measure : int; beat_unit : int }

let microseconds_per_quarter = function
  | None -> 500_000
  | Some t ->
      int_of_float
        (Float.round (60_000_000.0 /. t.bpm *. float_of_int t.beat_unit /. 4.0))

let tick_of_seconds ~us_per_quarter s =
  let ticks_per_second =
    float_of_int ticks_per_quarter /. (float_of_int us_per_quarter /. 1_000_000.0)
  in
  int_of_float (Float.round (s *. ticks_per_second))

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

let add_tempo buf ~us_per_quarter =
  add_vlq buf 0;
  Buffer.add_string buf "\xFF\x51\x03";
  Buffer.add_char buf (Char.chr ((us_per_quarter asr 16) land 0xff));
  Buffer.add_char buf (Char.chr ((us_per_quarter asr 8) land 0xff));
  Buffer.add_char buf (Char.chr (us_per_quarter land 0xff))

(* Time signature meta event: numerator, denominator as a power of two,
   24 MIDI clocks per metronome click, 8 32nds per quarter. *)
let add_time_signature buf { beats_per_measure; beat_unit; _ } =
  let rec log2 n = if n <= 1 then 0 else 1 + log2 (n / 2) in
  add_vlq buf 0;
  Buffer.add_string buf "\xFF\x58\x04";
  Buffer.add_char buf (Char.chr (beats_per_measure land 0xff));
  Buffer.add_char buf (Char.chr (log2 beat_unit));
  Buffer.add_char buf (Char.chr 24);
  Buffer.add_char buf (Char.chr 8)

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

let tempo_track tempo =
  let buf = Buffer.create 24 in
  add_tempo buf ~us_per_quarter:(microseconds_per_quarter tempo);
  Option.iter (add_time_signature buf) tempo;
  add_meta_end_of_track buf;
  track_chunk buf

(* One instrument's notes -> one track, on its own channel. Every note
   becomes a Note On followed by a Note Off at its own resolved pitch; ties
   at the same tick are ordered Off-before-On so a note that reuses the
   previous one's pitch back-to-back doesn't leave a hanging note. *)
let instrument_track ~us_per_quarter ~channel ~tr ~name (notes : Score_generation.note list) =
  let events =
    notes
    |> List.concat_map (fun (n : Score_generation.note) ->
        let (Duration dur) = n.duration in
        let start = tick_of_seconds ~us_per_quarter n.time in
        let stop =
          max (start + 1) (tick_of_seconds ~us_per_quarter (n.time +. dur))
        in
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
let write_layer_midi ?tempo ~tr filename (entries : Score_generation.entry list) =
  let notes = entries |> List.concat_map (fun (e : Score_generation.entry) -> e.notes) in
  let instruments = distinct_instruments notes in
  let us_per_quarter = microseconds_per_quarter tempo in
  let tracks =
    instruments
    |> List.mapi (fun i instr ->
        let (InstrumentName name) = instr in
        let channel = i mod 16 in
        let notes_for_instr = notes |> List.filter (fun (n : Score_generation.note) -> n.instrument = instr) in
        instrument_track ~us_per_quarter ~channel ~tr ~name notes_for_instr)
  in
  let oc = open_out_bin filename in
  Buffer.output_buffer oc (header_chunk ~ntracks:(1 + List.length tracks));
  Buffer.output_buffer oc (tempo_track tempo);
  List.iter (Buffer.output_buffer oc) tracks;
  close_out oc

(* Each layer becomes its own file ([prefix]_layer0.mid, [prefix]_layer1.mid,
   ...) so they can be imported into a DAW as separate parts. *)
let write_layers_midi ?tempo ~prefix ~tr
    (layers : Score_generation.entry list list) =
  layers
  |> List.iteri (fun i entries ->
      write_layer_midi ?tempo ~tr (Printf.sprintf "%s_layer%d.mid" prefix i) entries)

(* ---- playback data for the GUI ---- *)

(* The notes of one generated score as JSON, for the GUI's MIDI preview: per
   variant, per layer, one [time, duration, midi note, velocity, instrument]
   array per note. Times are seconds (after quantization when that is on);
   the instrument is its index in [instrs], so the GUI can give each one its
   own channel across all layers. Same pitch/velocity mapping as the .mid
   files above, so a preview and an exported file can't disagree. Output
   only - nothing here comes from, or goes into, the structure formula. *)
let playback_json ~tr ~instrs (variants : Score_generation.entry list list list) =
  let instr_index instr =
    let rec find i = function
      | [] -> 0
      | x :: rest -> if x = instr then i else find (i + 1) rest
    in
    find 0 instrs
  in
  let note_json (n : Score_generation.note) =
    let (Duration dur) = n.duration in
    Printf.sprintf "[%.4f,%.4f,%d,%d,%d]" n.time dur
      (midi_note_of_pitch ~tr n.pitch)
      (velocity_of_dynamic n.dynamic)
      (instr_index n.instrument)
  in
  let layer_json (entries : Score_generation.entry list) =
    entries
    |> List.concat_map (fun (e : Score_generation.entry) -> e.notes)
    |> List.map note_json |> Parameters.json_array
  in
  let variant_json layers =
    Parameters.json_obj [ ("layers", Parameters.json_array (List.map layer_json layers)) ]
  in
  Parameters.json_obj
    [
      ( "instruments",
        Parameters.json_array
          (List.map (fun (InstrumentName name) -> Parameters.json_string name) instrs) );
      ("variants", Parameters.json_array (List.map variant_json variants));
    ]
