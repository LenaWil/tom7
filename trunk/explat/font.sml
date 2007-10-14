
functor FontFn(F : FONTARG) :> FONT =
struct

    open F
    val fontsurf = F.surf

    val chars = Array.array(255, 0)
    val () =
        (* invert the map *)
        Util.for 0 (size F.charmap - 1)
        (fn i =>
         Array.update(chars, ord (String.sub(F.charmap, i)), i))

    exception Font of string

    fun sizex_plain s = size s * (width - overlap)
    fun draw_plain (surf, x, y, s) =
        Util.for 0 (size s - 1)
        (fn i =>
         SDL.blit(fontsurf, 
                  Array.sub(chars, ord (String.sub(s, i))) * width, 0, width, height,
                  surf, x + i * (width - overlap), y))

    fun draw _ = raise Font "unimplemented"
    fun drawcenter _ = raise Font "unimplemented"
    fun drawlines _ = raise Font "unimplemented"
    fun length _ = raise Font "unimplemented"
    fun lines _ = raise Font "unimplemented"
    fun sizex _ = raise Font "unimplemented"
    fun substr _ = raise Font "unimplemented"
    fun prefix _ = raise Font "unimplemented"
    fun suffix _ = raise Font "unimplemented"
    fun truncate _ = raise Font "unimplemented"
    fun pad _ = raise Font "unimplemented"
end
