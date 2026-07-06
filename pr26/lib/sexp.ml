type t = Atom of string | List of t list

type token = LParen | RParen | Tok of string

let tokenize src =
  let n = String.length src in
  let tokens = ref [] in
  let i = ref 0 in
  let buf = Buffer.create 32 in
  let flush () =
    if Buffer.length buf > 0 then begin
      tokens := Tok (Buffer.contents buf) :: !tokens;
      Buffer.clear buf
    end
  in
  while !i < n do
    (match src.[!i] with
    | '(' -> flush (); tokens := LParen :: !tokens
    | ')' -> flush (); tokens := RParen :: !tokens
    | ';' ->
        flush ();
        incr i;
        while !i < n && src.[!i] <> '\n' do incr i done;
        decr i
    | ' ' | '\t' | '\n' | '\r' -> flush ()
    | c -> Buffer.add_char buf c);
    incr i
  done;
  flush ();
  List.rev !tokens

let rec parse_expr = function
  | [] -> Error "unexpected end of input"
  | LParen :: rest -> parse_list [] rest
  | RParen :: _ -> Error "unexpected ')'"
  | Tok s :: rest -> Ok (Atom s, rest)

and parse_list acc = function
  | [] -> Error "unclosed '('"
  | RParen :: rest -> Ok (List (List.rev acc), rest)
  | tokens -> (
      match parse_expr tokens with
      | Error e -> Error e
      | Ok (expr, rest) -> parse_list (expr :: acc) rest)

let of_string src =
  let rec parse_all acc tokens =
    match tokens with
    | [] -> Ok (List.rev acc)
    | _ -> (
        match parse_expr tokens with
        | Error e -> Error e
        | Ok (expr, rest) -> parse_all (expr :: acc) rest)
  in
  tokenize src |> parse_all []
