(* Setlist event for mini game. *)
signature MINIGAME =
sig
  exception Minigame of string

  val game : Setlist.songinfo -> unit
end
