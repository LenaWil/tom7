
structure MLton =
struct

    fun size _ = 0
    fun shareAll () = ()

end

(* Can't compile my fsutil because no posix on sml/nj windows *)
structure FSUtil =
struct

    (* annotations needed to work around bug in sml/nj, too, ugh *)
    fun dirapp (_ : { name : string } -> unit ) (_ : string) = ()

end