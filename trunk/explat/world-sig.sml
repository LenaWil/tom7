(* The world is a the grid of tiles, sized 2^28 x 2^28, in which the
   entire game takes place. (Since each tile is 16x16, this gives the
   world (2^32)^2 pixels.) This is of course represented sparsely.
   
*)

signature WORLD =
sig

  val maskat : int * int -> Tile.mask
  val tileat : int * int -> Tile.tile

  (* XXX on top of WORLD we should build 
     a VIEW that allows us to do 90 degree rotations
     of the world. *)

end
