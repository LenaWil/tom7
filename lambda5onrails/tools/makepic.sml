
structure Makepic =
struct

  val width = 1024
  val str = StringUtil.readfile "dump.txt"

  val height = 1 + (size str div width)

  val a = Array.tabulate(4 * width * height,
                         fn x =>
                         let val c = if x div 4 >= size str
                                     then 0w0
                                     else Word8.fromInt (ord (String.sub(str, x div 4)))
                         in
                           (case x mod 4 of
                              (* R *)
                              0 => c * 0w2
                            | 1 => c * 0w2
                            | 2 => c
                            (* A *)
                            | _ => 0w255 : Word8.word)
                         end)

  val () = PNGsave.save ("dump.png", width, height, a)

end