
structure Tile :> TILE =
struct

  (* the mask tells us where things can walk *)
  datatype slope = LM | MH | HM | ML
  datatype mask = MEMPTY | MSOLID | MRAMP of slope (* | MCEIL of slope *)

  (* need to implement this somehow.. *)
  datatype tile = TILE_XXX

  val TILEW = 16
  val TILEH = 16

  fun clipmask MEMPTY _ = false
    | clipmask MSOLID _ = true
    | clipmask (MRAMP LM) (x, y) = y >= (8 + (7 - x div 2))
    | clipmask (MRAMP MH) (x, y) = y >= (7 - x div 2)
    | clipmask (MRAMP _) _ = false (* FIXME! *)

end