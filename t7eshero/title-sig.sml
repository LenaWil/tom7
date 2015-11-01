
signature TITLE =
sig

    (* Display the menu. Returns a show to play,
       and the current profile. *)
    val loop : unit -> { show : Setlist.showinfo,
                         profile : Profile.profile }

end
