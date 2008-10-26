
signature TITLE =
sig

    (* Display the menu. Returns a midi file to play,
       a selected difficulty level, a slowfactor, and
       then current profile. *)
    val loop : unit -> { midi : string,
                         difficulty : Hero.difficulty,
                         slowfactor : int,
                         profile : Profile.profile }

end
