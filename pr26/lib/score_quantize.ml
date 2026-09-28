(* Optional post-processing of a finished score: snaps every time value to
   a notatable rhythm (see [Quantize]) at a given tempo, so the score and
   MIDI files line up with bars, beats and tuplets when imported into
   notation software.

   Works on the final [entry]/[note] values only, after generation is
   complete - nothing in [Score_generation] depends on it. Each layer is
   quantized on its own grid (one layer = one MIDI file = one part). *)

open Parameters
open Score_generation

type settings = {
  bpm : float; (* beats per minute; one beat = one [Quantize] beat *)
  quantize : Quantize.settings;
}

(* What gets snapped, per entry:
   - its time, and time + entry delay (= where the next entry starts, so
     both snap the same way and consecutive entries stay back to back);
   - each note's end. Notes keep starting at their entry's time.
   A rest is an entry without notes whose duration is its entry delay, so
   it is covered by the first rule. *)
let quantize_layer s (entries : entry list) : entry list =
  if entries = [] then entries
  else
    let beats t = t *. s.bpm /. 60.0 in
    let seconds q = Quantize.Q.to_float q *. 60.0 /. s.bpm in
    let note_end (n : note) =
      let (Duration d) = n.duration in
      n.time +. d
    in
    let points =
      entries
      |> List.concat_map (fun (e : entry) ->
          e.time :: (e.time +. e.entrydelay) :: List.map note_end e.notes)
      |> List.map beats
    in
    let r = Quantize.quantize s.quantize points in
    List.map
      (fun (e : entry) ->
        let onset = Quantize.snap r (beats e.time) in
        let next = Quantize.snap r (beats (e.time +. e.entrydelay)) in
        let time = seconds onset in
        let entrydelay = seconds (Quantize.Q.sub next onset) in
        let notes =
          List.map
            (fun (n : note) ->
              let d =
                Quantize.snap_duration s.quantize r ~onset (beats (note_end n))
              in
              { n with time; duration = Duration (seconds d) })
            e.notes
        in
        let duration =
          if e.is_rest then Some (Duration entrydelay)
          else uniform_value (fun (n : note) -> n.duration) notes
        in
        { e with time; entrydelay; notes; duration })
      entries

let quantize_score s (variants : entry list list list) =
  List.map (List.map (quantize_layer s)) variants
