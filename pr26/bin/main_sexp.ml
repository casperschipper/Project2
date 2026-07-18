open Pr26.Parameters
open Pr26.Structure_formula
open Pr26.Score_generation

let render file =
  match Parse.read_file file with
  | Error errors -> print_located_errors file errors
  | Ok sf ->
      let instrs =
        match sf.instr_list with ParameterList arr -> Array.to_list arr
      in
      let layers = build_score sf in
      print_layers instrs layers;
      write_notes_score "score.projekt2" instrs layers;
      write_entries_score "score_entries.projekt2" instrs ~density:sf.density layers;
      print_endline "Score written to score.projekt2 and score_entries.projekt2"

let watch file =
  let mtime () = (Unix.stat file).Unix.st_mtime in
  let last = ref (mtime ()) in
  Printf.printf "Watching %s for changes (Ctrl+C to stop)...\n%!" file;
  render file;
  while true do
    Unix.sleepf 0.3;
    match mtime () with
    | m when m <> !last ->
        last := m;
        Printf.printf "\n%s changed, re-rendering...\n%!" file;
        render file
    | _ -> ()
    | exception Unix.Unix_error (Unix.ENOENT, _, _) -> ()
  done

let () =
  let watch_mode = ref false in
  let file = ref None in
  Arg.parse
    [ ("--watch", Arg.Set watch_mode, "Re-render whenever the input file changes");
      ("-w", Arg.Set watch_mode, "Alias for --watch") ]
    (fun arg -> file := Some arg)
    "main_sexp <file.sexp> [--watch]";
  match !file with
  | None ->
      prerr_endline "Usage: main_sexp <file.sexp> [--watch]";
      exit 1
  | Some file -> if !watch_mode then watch file else render file
