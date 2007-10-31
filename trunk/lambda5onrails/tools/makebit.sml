
structure Makebit =
struct

  val width = 6 (* inches *)
            * 200 (* bits per inch *)

  val str = StringUtil.readfile "dump.txt"
  val bits = Vector.tabulate
    (size str * 8, (* probably could do seven for this code; general *)
     fn i =>
     let
       val c = Word8.fromInt (ord (String.sub(str, i div 8)))
       val bit = i mod 8
     in
       (* msb to lsb *)
       0w0 <> Word8.andb (c, Word8.<<(0w1, 0w7 - Word.fromInt bit))
     end)


  val height = 1 + (Vector.length bits div width)

  val a = Array.tabulate(4 * width * height,
                         fn x =>
                         let val c = 
                           if x div 4 >= Vector.length bits
                           then 0wxFF (* oob - white *)
                           else if Vector.sub(bits, x div 4)
                                then 0wx00 (* black *)
                                else 0wxFF (* white *)
                         in
                           (case x mod 4 of
                              0 => c
                            | 1 => c
                            | 2 => c
                            (* A *)
                            | _ => 0w255 : Word8.word)
                         end)

  val () = PNGsave.save ("bits.png", width, height, a)

end