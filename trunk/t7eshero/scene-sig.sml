(* The SceneFn functor takes the screen as its argument. *)
signature SCENE =
sig

  (* how many ticks forward do we look when drawing? *)
  val MAXAHEAD : int

  (* how many MIDI ticks in the past do we draw? *)
  val DRAWLAG : int

  (* initfromsong (song, numer, denom)
     Initialize the scene (song title, etc.) from the song.
     Numerator and denominator ar our progress through the
     setlist. *)
  val initfromsong : Setlist.songinfo * int * int -> unit

  val clear : unit -> unit

  (* Set the current time signature by numerator and
     denominator (e.g. 3, 4 = 3/4 time). *)
  val settimesig : int * int -> unit

  (* addspan (finger, spanstart, spanend)
     Add a span of a note.
     *)
  val addspan : int * int * int -> unit

  (* addstar (finger, stary, evt)
     Add a note to be drawn as a star or dot.
     *)
  val addstar : int * int * Match.scoreevt -> unit

  (* addbar (b, t) *)
  val addbar : Hero.bar * int -> unit

  (* addtext (text, ticks) *)
  val addtext : string * int -> unit

  val draw : unit -> unit

  (* XXX this should have setter. *)
  val background : Setlist.background ref

end
