
structure Animate :> ANIMATE =
struct

    val r = ref 0
    fun now () = !r
    (* XXX overflow *)
    fun increment () = r := !r + 1
end
