(* A player's profile stores personal records, finished songs, achievements, etc. *)
signature PROFILE =
sig

    (* an individual profile *)
    type profile

    (* for the whole database, serialize to and unserialize from disk. *)
    val save : unit -> unit
    val load : unit -> unit

    val all : unit -> profile list

    datatype achievement =
        (* get perfect on a song *)
        PerfectMatch

    (* accessors *)
    val name : profile -> string
    val pic : profile -> string (* filename of image *)
    val records : profile -> (Setlist.songid * Record.record list) list
    val achievements : profile -> (achievement * Setlist.songid option * IntInf.int) list
    val lastused : profile -> IntInf.int

    (* posessions, fans, etc. *)

    (* mutators *)
    val setname : profile -> string -> unit
    val setpic  : profile -> string -> unit
    val setrecords : profile -> (Setlist.songid * Record.record list) list -> unit
    val setachievements : profile -> (achievement * Setlist.songid option * IntInf.int) list -> unit
    val setlastused : profile -> IntInf.int -> unit

end
