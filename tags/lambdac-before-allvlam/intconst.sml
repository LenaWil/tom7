
(* Integer constants throughout the compiler. This makes it
   easier to switch from 32-bit integers to 64, or infinite
   precision.

   XXX should be abstract!

   *)

structure IntConst =
struct

    type intconst = Word32.word
    val tostring = Word32.toString


    val toString = tostring
end