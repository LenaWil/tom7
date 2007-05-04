
(* This allows access to the clipping mask of the world,
   in configuration space (robot's bounding box).
   *)

signature CLIP =
sig

    type config

    (* For a 1x2 tile robot. *)
    val std : config

    (* true if the robot cannot inhabit this pixel. *)
    val clipped : config -> int * int -> bool

end
