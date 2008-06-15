(* A player's profile stores personal records, finished songs,
   achievements, etc. *)
signature PROFILE =
sig

    (* an individual profile *)
    type profile

    (* for the whole database, serialize to and unserialize from disk. *)
    val save : unit -> unit
    val load : unit -> unit

    val all : unit -> profile list

    (* accessors *)
    val name : profile -> string
    val pic : profile -> string (* filename of image *)

    (* per-song records *)
    type 'a record = { best : 'a, 
                       > : 'a * 'a -> bool,
                       (* seconds since epoch *)
                       when : IntInf.int,
                       tostring : 'a -> string }

end
