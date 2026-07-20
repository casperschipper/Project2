open Pr26.Parameters
open Pr26.Structure_formula
open Pr26.Score_generation

(* Where the generated artefacts go. Defaults to the cwd (the historical
   behaviour); the GUI passes --out-dir so repeated validation runs don't
   scribble over the composer's working directory. *)
let out_dir = ref "."
let in_out_dir name = Filename.concat !out_dir name

let read_whole_file path =
  let ic = open_in_bin path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () -> really_input_string ic (in_channel_length ic))

let generate sf =
  let instrs = match sf.instr_list with ParameterList arr -> Array.to_list arr in
  let layers = build_score sf in
  write_notes_score (in_out_dir "score.projekt2") instrs layers;
  write_entries_score (in_out_dir "score_entries.projekt2") instrs
    ~density:sf.density layers;
  Pr26.Midi_export.write_layers_midi ~prefix:(in_out_dir "score") layers;
  (instrs, layers)

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
      let instrs, layers = generate sf in
      print_layers instrs layers;
      Printf.printf
        "Score written to %s, %s and %s\n"
        (in_out_dir "score.projekt2")
        (in_out_dir "score_entries.projekt2")
        (in_out_dir "score_layer<N>.mid");
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
      let generated, gen_log = capture_stdout (fun () -> generate sf) in
      let log = json_string (parse_log ^ gen_log) in
      match generated with
      | Error exn ->
          emit
            (json_of_diagnostics ~ok:false ~errors:[ crash_diagnostic exn ]
               ~warnings ~extra:[ ("log", log) ]);
          false
      | Ok (_instrs, _layers) ->
          let file_field name key =
            match read_whole_file (in_out_dir name) with
            | contents -> [ (key, json_string contents) ]
            | exception _ -> []
          in
          emit
            (json_of_diagnostics ~ok:true ~errors:[] ~warnings
               ~extra:
                 (("log", log)
                 :: (file_field "score.projekt2" "score"
                    @ file_field "score_entries.projekt2" "entries")));
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
        "Directory for generated score/MIDI files (default: current directory)" )
    ]
    (fun arg -> file := Some arg)
    "main_sexp <file.sexp> [--watch] [--json] [--out-dir DIR]";
  match !file with
  | None ->
      prerr_endline
        "Usage: main_sexp <file.sexp> [--watch] [--json] [--out-dir DIR]";
      exit 1
  | Some file ->
      if !watch_mode then watch file !json_mode
      else if !json_mode then exit (if render_json file then 0 else 1)
      else exit (if render file then 0 else 1)
