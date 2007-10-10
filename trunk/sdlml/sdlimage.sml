
structure SDLImage =
struct

  val null = MLton.Pointer.null
  fun check (ref p) = if p = null then raise Invalid else ()
  fun clear r = r := null


end