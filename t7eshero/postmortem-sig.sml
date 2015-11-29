(* Setlist event that shows stats from the previous song. *)
signature POSTMORTEM =
sig
  exception Postmortem of string

  val loop : unit -> unit
end