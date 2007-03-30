(* The world is populated by tiles. *)

signature TILE =
sig

  (* the mask tells us where things can walk *)
  datatype slope = LM | MH | HM | ML
  datatype mask = MEMPTY | MSOLID | MRAMP of slope (* | MCEIL of slope *)

  (* need to implement this somehow.. *)
  datatype tile = TILE_XXX

end
