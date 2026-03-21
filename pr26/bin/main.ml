let print_int_list label lst =
  Printf.printf "%s:\n [%s]\n" label
    (lst |> List.map string_of_int |> String.concat "; ")


let () = 
  print_string "lets run some simple tests\n";
  let open Pr26.Basics in
  ratio [(1,1);(42,3);(3,10)] |> Seq.take 100 |> List.of_seq |> print_int_list "ratio (1,1) (42,3) (3,10)"