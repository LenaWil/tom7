
structure PNGsave =
struct

  (* zero-terminated filename, width, height, w*h*4 RGBA bytes *)
  local
    val pngsave_ = _import "pngsave" : string * int * int * Word8.word array -> unit ;
  in
    fun save (name, w, h, a : Word8.word array) = pngsave_ (name ^ "\000", w, h, a)
  end
end
