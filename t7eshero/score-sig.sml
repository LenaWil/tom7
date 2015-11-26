signature SCORE =
sig

  exception Score of string

  type track = (int * (Match.label * MIDI.event)) list

  (* Load a score in MIDI format. Returns its MIDI division and the raw
     tracks, each of which is just a list of MIDI events with ticks. *)
  val fromfile : string -> int * (int * MIDI.event) list list

  (* Add labels to each track indicating its type (Control, Music, etc.) *)
  val label : int -> int -> (int * MIDI.event) list list -> track list

  val slow : int -> track -> track

  val add_measures : int -> track -> track

  val endify : track -> track

  val delay : int -> track -> track

end