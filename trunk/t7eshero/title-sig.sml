
signature TITLE =
sig

    (* Display the menu. Returns a midi file to play,
       a selected difficulty level, a slowfactor, and
       then current profile. *)
    val loop : unit -> { song : Setlist.songinfo,
                         difficulty : Hero.difficulty,
                         profile : Profile.profile }

end
