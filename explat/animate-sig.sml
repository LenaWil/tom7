
(* All animations are keyed to the same
   (modular) integer timestep *)
signature ANIMATE =
sig

    val now : unit -> int
    val increment : unit -> unit

end
