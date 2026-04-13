  type byte = int (* invariant: 0–255 *)
  type message = byte * byte * byte
  type stream = message Seq.t

  let byte n = n land 0xFF (* safe constructor *)

  (* Common message constructors *)
  let note_on ~channel ~note ~velocity =
    (byte (0x90 lor (channel land 0x0F)), byte note, byte velocity)

  let note_off ~channel ~note ~velocity =
    (byte (0x80 lor (channel land 0x0F)), byte note, byte velocity)

  let control_change ~channel ~controller ~value =
    (byte (0xB0 lor (channel land 0x0F)), byte controller, byte value)

  (* Stream helpers *)
  let of_list = List.to_seq
  let to_list = List.of_seq

