open Pr26.Parameters
open Pr26.Structure_formula
open Pr26.Score_generation

let () =
  match Parse.read_file "formula.sexp" with
  | Error errors -> print_errors "formula.sexp" errors
  | Ok sf ->
      let instrs =
        match sf.instr_list with ParameterList arr -> Array.to_list arr
      in
      let layers = build_score sf in
      print_layers instrs layers;
      write_notes_score "score.projekt2" instrs layers;
      write_entries_score "score_entries.projekt2" instrs layers;
      print_endline "Score written to score.projekt2 and score_entries.projekt2"
