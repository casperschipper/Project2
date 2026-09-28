open Pr26.Parameters
open Pr26.Structure_formula
open Pr26.Score_generation
open Pr26.Score_printing

(* Where the generated artefacts go. Defaults to the cwd (the historical
   behaviour); the GUI passes --out-dir so repeated validation runs don't
   scribble over the composer's working directory. *)
let out_dir = ref "."
let in_out_dir name = Filename.concat !out_dir name

(* Opt-in, JSON-only (see [render_json]): the plain-text [render] path has no
   format to carry this in and no consumer needing one - "manuals and notes/
   debug_output.md" frames the debug stream as input to a future
   visualisation tool, not something read as text. *)
let debug_mode = ref false

(* Opt-in post-processing: snap the finished score to notatable rhythms,
   tuplets included (see [Pr26.Quantize]). [None] leaves the score exactly
   as generated. *)
let quantize_bpm = ref None
let meter = ref (4, 4)
let beat_division = ref Pr26.Quantize.default_settings.beat_division
let tuplets = ref Pr26.Quantize.default_settings.tuplets

(* "3,5,7", or "none" for no tuplets. *)
let set_tuplets str =
  if String.trim str = "none" then tuplets := []
  else
    let parse s =
      match int_of_string_opt (String.trim s) with
      | Some j when j >= 3 && j mod 2 = 1 -> j
      | _ ->
          raise
            (Arg.Bad
               ("--tuplets expects odd numbers >= 3 separated by commas (e.g. \
                 3,5,7) or \"none\", got " ^ str))
    in
    tuplets := List.map parse (String.split_on_char ',' str)

(* Only halving is ever done below the beat, so only powers of two mean
   anything here; the GUI offers exactly these. *)
let set_beat_division n =
  if List.mem n [ 1; 2; 4; 8; 16 ] then beat_division := n
  else raise (Arg.Bad "--beat-division expects 1, 2, 4, 8 or 16")

let set_meter str =
  let is_pow2 n = n > 0 && n land (n - 1) = 0 in
  match String.split_on_char '/' str with
  | [ n; d ] -> (
      match (int_of_string_opt n, int_of_string_opt d) with
      | Some n, Some d when n >= 1 && is_pow2 d -> meter := (n, d)
      | _ -> raise (Arg.Bad ("--meter expects N/D with D a power of two, got " ^ str)))
  | _ -> raise (Arg.Bad ("--meter expects N/D, e.g. 3/4, got " ^ str))

(* The score after optional quantization, plus the tempo the MIDI files
   should carry (only when quantized - otherwise their fixed default). *)
let postprocess variants =
  match !quantize_bpm with
  | None -> (variants, None)
  | Some bpm ->
      let beats_per_measure, beat_unit = !meter in
      let settings =
        {
          Pr26.Score_quantize.bpm;
          quantize =
            {
              Pr26.Quantize.default_settings with
              beats_per_measure;
              beat_division = !beat_division;
              tuplets = !tuplets;
            };
        }
      in
      ( Pr26.Score_quantize.quantize_score settings variants,
        Some { Pr26.Midi_export.bpm; beats_per_measure; beat_unit } )

let read_whole_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

(* One [score.projekt2]/[score_entries.projekt2]/[score_layer<N>.mid] set per
   variant. With a single variant (by far the common case, and every formula
   written before N-VARIANTS existed) the names are exactly what they always
   were - no variant-numbered file appears at all. Only with more than one
   variant do the per-variant names show up, alongside the existing ones. *)
let variant_score_name n v =
  if n = 1 then "score.projekt2" else Printf.sprintf "score_variant%d.projekt2" v

let variant_entries_name n v =
  if n = 1 then "score_entries.projekt2"
  else Printf.sprintf "score_variant%d_entries.projekt2" v

let variant_midi_prefix n v =
  if n = 1 then "score" else Printf.sprintf "score_variant%d" v

let generate sf =
  let instrs = match sf.instr_list with ParameterList arr -> Array.to_list arr in
  let variants, tempo = postprocess (build_score sf) in
  let n = List.length variants in
  variants
  |> List.iteri (fun v layers ->
      write_notes_score (in_out_dir (variant_score_name n v)) instrs layers;
      write_entries_score
        (in_out_dir (variant_entries_name n v))
        instrs ~density:sf.density layers;
      Pr26.Midi_export.write_layers_midi ?tempo
        ~prefix:(in_out_dir (variant_midi_prefix n v))
        ~tr:sf.tr layers);
  (instrs, variants)

(* ------------------------------------------------------------------ *)
(* Human-readable mode (unchanged behaviour, plus exit codes).         *)
(* ------------------------------------------------------------------ *)
let render file =
  match Parse.read_file file with
  | Error (errors, warnings) ->
      print_diagnostics (file ^ " errors") errors;
      if warnings <> [] then print_diagnostics (file ^ " warnings") warnings;
      false
  | Ok (sf, warnings) ->
      if warnings <> [] then print_diagnostics (file ^ " warnings") warnings;
      let instrs, variants = generate sf in
      let n = List.length variants in
      variants
      |> List.iteri (fun v layers ->
          if n > 1 then Printf.printf "\n=== variant %d ===\n" v;
          print_layers instrs layers);
      if n = 1 then
        Printf.printf "Score written to %s, %s and %s\n"
          (in_out_dir "score.projekt2")
          (in_out_dir "score_entries.projekt2")
          (in_out_dir "score_layer<N>.mid")
      else
        Printf.printf "%d variants written to %s (score_variant0.. through score_variant%d..)\n"
          n !out_dir (n - 1);
      true

(* ------------------------------------------------------------------ *)
(* JSON mode, for the GUI.                                             *)
(*                                                                     *)
(* Emits exactly one JSON object on stdout and nothing else, so the     *)
(* caller can parse stdout wholesale. Score generation is wrapped       *)
(* because several inconsistencies the composer can express are not     *)
(* yet diagnosed and instead raise at generation time (a table index    *)
(* past the end of its list is the common one - see lookup_index).      *)
(* Those surface as a synthetic "engine-crash" diagnostic rather than   *)
(* killing the process, so the GUI can still show everything else.      *)
(* ------------------------------------------------------------------ *)
let crash_diagnostic exn =
  { location = [ Key KGlobal ];
    severity = Severity.Error;
    problem =
      ParseError
        ("the engine could not generate a score from this formula: "
        ^ Printexc.to_string exn
        ^ " (this usually means a table index points past the end of its \
           list, or a selection principle was left with nothing to choose \
           from)") }

(* Parsing and generation both write progress/debug lines to stdout. In JSON
   mode stdout must carry the JSON object alone, so fd 1 is redirected to a
   temp file for the duration and the captured text is handed back as the
   "log" field - the GUI's output screen shows it, and it is where the
   per-note "IMPOSSIBLE" annotations currently live. *)
let capture_stdout f =
  let tmp = Filename.temp_file "pr26-capture" ".log" in
  flush stdout;
  let saved = Unix.dup Unix.stdout in
  let fd = Unix.openfile tmp [ Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC ] 0o600 in
  Unix.dup2 fd Unix.stdout;
  Unix.close fd;
  let result = try Ok (f ()) with exn -> Error exn in
  flush stdout;
  Unix.dup2 saved Unix.stdout;
  Unix.close saved;
  let log = try read_whole_file tmp with _ -> "" in
  (try Sys.remove tmp with _ -> ());
  (result, log)

let render_json file =
  let emit json = print_string json; print_newline (); flush stdout in
  let parsed, parse_log = capture_stdout (fun () -> Parse.read_file file) in
  let parsed = match parsed with Ok r -> r | Error exn -> raise exn in
  match parsed with
  | Error (errors, warnings) ->
      emit
        (json_of_diagnostics ~ok:false ~errors ~warnings
           ~extra:[ ("log", json_string parse_log) ]);
      false
  | Ok (sf, warnings) -> (
      Pr26.Debug_log.reset ();
      Pr26.Debug_log.enabled := !debug_mode;
      let generated, gen_log = capture_stdout (fun () -> generate sf) in
      let log = json_string (parse_log ^ gen_log) in
      match generated with
      | Error exn ->
          emit
            (json_of_diagnostics ~ok:false ~errors:[ crash_diagnostic exn ]
               ~warnings ~extra:[ ("log", log) ]);
          false
      | Ok (_instrs, variants) ->
          let n = List.length variants in
          let file_field name key =
            match read_whole_file (in_out_dir name) with
            | contents -> [ (key, json_string contents) ]
            | exception _ -> []
          in
          (* A single variant (the common case) keeps the flat "score"/
             "entries" fields the GUI has always read. More than one
             variant reports an array instead - there's no longer one
             score/entries pair to flatten. *)
          let result_fields =
            if n = 1 then
              file_field "score.projekt2" "score"
              @ file_field "score_entries.projekt2" "entries"
            else
              let variant_obj v =
                json_obj
                  (file_field (variant_score_name n v) "score"
                  @ file_field (variant_entries_name n v) "entries")
              in
              [ ("variants", json_array (List.init n variant_obj)) ]
          in
          (* Only a fact about *this* generated run (depends on the random
             seed and whatever actually got drawn), not about the formula's
             static shape - so unlike every other warning here, it can only
             be computed after generation succeeds, not by
             [Structure_formula]'s own validation. *)
          let too_strict_warnings =
            match count_interval_restrictions_too_strict variants with
            | 0 -> []
            | count ->
                [
                  {
                    location = [ Key KHarmony; Key KMatrix ];
                    severity = Severity.Warning;
                    problem = IntervalRestrictionsTooStrict count;
                  };
                ]
          in
          let debug_field =
            if !debug_mode then [ ("debug", Pr26.Debug_log.to_json ()) ]
            else []
          in
          emit
            (json_of_diagnostics ~ok:true ~errors:[]
               ~warnings:(warnings @ too_strict_warnings)
               ~extra:(("log", log) :: result_fields @ debug_field));
          true)

let watch file json =
  let mtime () = (Unix.stat file).Unix.st_mtime in
  let last = ref (mtime ()) in
  if not json then
    Printf.printf "Watching %s for changes (Ctrl+C to stop)...\n%!" file;
  ignore (if json then render_json file else render file);
  while true do
    Unix.sleepf 0.3;
    match mtime () with
    | m when m <> !last ->
        last := m;
        if not json then Printf.printf "\n%s changed, re-rendering...\n%!" file;
        ignore (if json then render_json file else render file)
    | _ -> ()
    | exception Unix.Unix_error (Unix.ENOENT, _, _) -> ()
  done

let () =
  let watch_mode = ref false in
  let json_mode = ref false in
  let file = ref None in
  Arg.parse
    [ ("--watch", Arg.Set watch_mode, "Re-render whenever the input file changes");
      ("-w", Arg.Set watch_mode, "Alias for --watch");
      ( "--json",
        Arg.Set json_mode,
        "Emit diagnostics and score as a single JSON object on stdout" );
      ( "--out-dir",
        Arg.Set_string out_dir,
        "Directory for generated score/MIDI files (default: current directory)" );
      ( "--debug",
        Arg.Set debug_mode,
        "Include a machine-readable \"debug\" event log in the --json output \
         (no effect without --json)" );
      ( "--quantize",
        Arg.Float
          (fun bpm ->
            if bpm <= 0.0 then raise (Arg.Bad "--quantize expects a tempo > 0");
            quantize_bpm := Some bpm),
        "BPM Snap the finished score to notatable rhythms (with tuplets) at \
         this tempo; MIDI files then carry this tempo and --meter" );
      ( "--meter",
        Arg.String set_meter,
        "N/D Time signature for --quantize (default 4/4)" );
      ( "--beat-division",
        Arg.Int set_beat_division,
        "N Finest plain division of a beat for --quantize: 1, 2, 4, 8 or 16 \
         (default 4)" );
      ( "--tuplets",
        Arg.String set_tuplets,
        "LIST Tuplets --quantize may use, e.g. 3,5,7 (the default), or none" )
    ]
    (fun arg -> file := Some arg)
    "main_sexp <file.sexp> [--watch] [--json] [--debug] [--out-dir DIR] \
     [--quantize BPM [--meter N/D] [--beat-division N] [--tuplets LIST]]";
  match !file with
  | None ->
      prerr_endline
        "Usage: main_sexp <file.sexp> [--watch] [--json] [--debug] [--out-dir \
         DIR]";
      exit 1
  | Some file ->
      if !watch_mode then watch file !json_mode
      else if !json_mode then exit (if render_json file then 0 else 1)
      else exit (if render file then 0 else 1)
