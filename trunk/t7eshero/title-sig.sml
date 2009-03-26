
signature TITLE =
sig

    (* Display the menu. Returns a midi file or show to play, 
       and the current profile. *)
    val loop : unit -> { song : Setlist.songinfo,
                         profile : Profile.profile }

end
