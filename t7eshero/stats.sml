
(* Accumulates statistics for Postmortem and on-line display.

   Sorta hacky. *)
structure Stats (* XXX :> STATS *) =
struct

    exception Stats of string

    type entry = { song : Setlist.songid, 
                   missnum : int ref,
                   start_time : Word32.word }

    val stack = ref nil : entry list ref

    fun head () = 
        case !stack of
            nil => raise Stats "asked for stats without starting"
          | h :: _ => h

    fun miss () = #missnum (head()) := !(#missnum(head())) + 1
    fun misses () = !(#missnum (head()))

    (* Delete all stats. *)
    fun clear () = stack := nil

    (* create *)
    fun push (s : Setlist.songid) =
        stack := { song = s, missnum = ref 0,
                   start_time = SDL.getticks() } :: !stack

end
