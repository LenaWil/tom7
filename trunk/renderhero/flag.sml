
(* intended to be opened and then sealed again
   (to FLAG) with the flags added *)
structure Flag =
struct
    type flag = int
    type flags = bool Array.array

    fun check a f = Array.sub(a, f)
    fun set a f = Array.update(a, f, true)
    fun clear a f = Array.update(a, f, false)

    fun nflags n () = Array.array(n, false)
end