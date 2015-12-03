(* Setlist event for advancing the story. *)
signature INTERLUDE =
sig
  val loop : Profile.profile -> Setlist.interlude -> unit
end