(* The world is populated by tiles. *)

signature TILE =
sig

  exception Tile of string

  (* the mask tells us where things can walk *)
  datatype slope = LM | MH | HM | ML
  datatype diag = NW | NE | SW | SE
  datatype mask = 
      MEMPTY 
    | MSOLID 
    | MRAMP of slope
    | MCEIL of slope
    | MDIAG of diag (* corner that is filled in *)
    | MLEFT of slope
    | MRIGHT of slope

  type tile

  val TILEW : int
  val TILEH : int

  (* is this pixel of the mask clipped? *)
  val clipmask : mask -> int * int -> bool

  (* drawat timestep tile surf pixel-x pixel-y  world-x world-y
     at a particular time step,
     draw the tile to the given surface at the
     given pixel coordinates.
     most tiles ignore world-x and world-y; they are used for
     effects like starfields, randomization, parallax, etc.
     *)
  val drawat : int * tile * SDL.surface * int * int * int * int -> unit
  (* or right now *)
  val draw : tile * SDL.surface * int * int * int * int -> unit

  val drawmask : mask * SDL.surface * int * int -> unit

  (* for serialization *)
  val toword   : tile -> Word32.word
  val fromword : Word32.word -> tile

end
