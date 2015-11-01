signature HIGHSCORES =
sig

    exception Highscores of string

    (* Is this record good enough to prompt the user and send to the server?
       (Same format as entry in Profiles.local_records.) *)
    val is_new_record : Setlist.songid * (string * Record.record * IntInf.int) -> bool

    (* Synchronize our high scores with the server's. *)
    val update : unit -> unit

end
