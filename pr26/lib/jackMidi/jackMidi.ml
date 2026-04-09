external open_midi_stream :
  (int, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t ->
  (int, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t ->
  (int -> unit) ->
  (int -> unit) ->
  unit = "open_midi_stream"

let playMidi midiInToOutFunction sample_rate =
  let open Seq in
  let ar_out =
    Bigarray.Array1.create Bigarray.Int8_unsigned Bigarray.c_layout 16384
  in
  let ar_in =
    Bigarray.Array1.create Bigarray.Int8_unsigned Bigarray.c_layout 16384
  in
  open_midi_stream ar_out ar_in
    (fun nframes ->
      for i = 0 to nframes - 1 do
        let midi_frame = i * 3 in
        let status, d1, d2 =
          midiInToOutFunction
            (ar_in.{midi_frame}, ar_in.{midi_frame + 1}, ar_in.{midi_frame + 2})
        in
        ar_out.{midi_frame} <- status;
        ar_out.{midi_frame + 1} <- d1;
        ar_out.{midi_frame + 2} <- d2
      done)
    (fun sr -> sample_rate := float_of_int sr)

let playMidiSeq (stream : Midi.stream) sample_rate =
  let seq_ref = ref stream in
  let ar_out =
    Bigarray.Array1.create Bigarray.Int8_unsigned Bigarray.c_layout 16384
  in
  let ar_in =
    Bigarray.Array1.create Bigarray.Int8_unsigned Bigarray.c_layout 16384
  in
  open_midi_stream ar_out ar_in
    (fun nframes ->
      let rec fill i s =
        if i >= nframes then seq_ref := s
        else begin
          let midi_frame = i * 3 in
          match s () with
          | Seq.Nil ->
              for j = i to nframes - 1 do
                let f = j * 3 in
                ar_out.{f} <- 0;
                ar_out.{f + 1} <- 0;
                ar_out.{f + 2} <- 0
              done;
              seq_ref := Seq.empty
          | Seq.Cons ((status, d1, d2), rest) ->
              ar_out.{midi_frame} <- status;
              ar_out.{midi_frame + 1} <- d1;
              ar_out.{midi_frame + 2} <- d2;
              fill (i + 1) rest
        end
      in
      fill 0 !seq_ref)
    (fun sr -> sample_rate := float_of_int sr)
