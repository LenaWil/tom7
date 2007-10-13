(* The world is populated by tiles. *)

signature TILE =
sig

  (* the mask tells us where things can walk *)
  datatype slope = LM | MH | HM | ML
  datatype mask = MEMPTY | MSOLID | MRAMP of slope (* | MCEIL of slope *)

  type tile

  val TILEW : int
  val TILEH : int

  (* is this pixel of the mask clipped? *)
  val clipmask : mask -> int * int -> bool

  (* draw the tile to the given surface at the
     given pixel coordinates *)
  val draw : tile * SDL.surface * int * int -> unit

  (* for serialization *)
  val toword   : tile -> Word32.word
  val fromword : Word32.word -> tile

end
