
(* Insist that we have 32-bit reals, so that we behave just like Box2D. *)
structure Real = Real32
val real = Real.fromInt
type real = Real.real

(* XXX uhhhh *)
structure Math =
struct
    val rm = IEEEReal.TO_NEAREST
    fun sqrt s = Real32.fromLarge rm (Math.sqrt (Real32.toLarge s))
    fun sin s = Real32.fromLarge rm (Math.sin (Real32.toLarge s))
    fun cos s = Real32.fromLarge rm (Math.cos (Real32.toLarge s))

    fun atan2 (a, b) = Real32.fromLarge rm (Math.atan2 (Real32.toLarge a,
                                                        Real32.toLarge b))

end