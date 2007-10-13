
structure Tile :> TILE =
struct

  (* the mask tells us where things can walk *)
  datatype slope = LM | MH | HM | ML
  datatype mask = MEMPTY | MSOLID | MRAMP of slope (* | MCEIL of slope *)

  (* need to implement this somehow.. *)
  datatype tile = Word32.word

  val TILEW = 16
  val TILEH = 16

  fun clipmask MEMPTY _ = false
    | clipmask MSOLID _ = true
    | clipmask (MRAMP LM) (x, y) = y >= (8 + (7 - x div 2))
    | clipmask (MRAMP MH) (x, y) = y >= (7 - x div 2)
    | clipmask (MRAMP _) _ = false (* FIXME! *)

  fun draw (t, surf, x, y) = () (* XXX FIXME *)

  fun toword x = x
  fun fromword x = x (* XXX check bounds *)

end