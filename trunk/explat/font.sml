
functor FontFn(F : FONTARG) :> FONT =
struct

    open F

    exception Font of string

    fun draw _ = raise Font "unimplemented"
    fun draw_plain _ = raise Font "unimplemented"
    fun drawcenter _ = raise Font "unimplemented"
    fun drawlines _ = raise Font "unimplemented"
    fun length _ = raise Font "unimplemented"
    fun lines _ = raise Font "unimplemented"

end
