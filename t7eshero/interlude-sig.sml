(* Setlist event for advancing the story. *)
signature INTERLUDE =
sig
  (* Message at top and bottom of screen *)
  val loop : Profile.profile -> string * string -> unit
end