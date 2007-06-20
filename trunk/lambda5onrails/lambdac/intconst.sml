
(* Integer constants throughout the compiler. This makes it
   easier to switch from 32-bit integers to 64, or infinite
   precision.

   XXX should be abstract!

   *)

(* XXX convert this to intinf? What does javascript support? *)
structure IntConst =
struct
  type intconst = Word32.word
  val tostring = Word32.toString

  val fromInt = Word32.fromInt
    
  val toString = tostring

  fun toReal x = Real.fromLargeInt (Word32.toLargeIntX x)
end
