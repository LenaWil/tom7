
structure Clip :> CLIP =
struct

   (* in pixels *)
   type config = { width : int,
                   height : int }

   val std = { width = Tile.TILEW,
               height = 2 * Tile.TILEH }

   val bullet = { width = 23, height = 10 }

   (* PERF slow! should precompute this! *)
   (* not possible to occupy this space if any
      pixel within the configuration rectangle 
      is solid. *)
   exception EarlyClip
   fun clipped { width, height } (px, py) =
       (Util.for 0 (width - 1)
        (fn xx =>
         Util.for 0 (height - 1)
         (fn yy =>
          let
              val x = xx + px
              val y = yy + py
              (* x,y are world-absolute coordinates.
                 we need the tile that's at those
                 coordinates: *)
              val tx = x div Tile.TILEW
              val ty = y div Tile.TILEH
              (* and the offset within that tile: *)
              val ox = x mod Tile.TILEW
              val oy = y mod Tile.TILEH
          in
              if Tile.clipmask (World.maskat (tx, ty)) (ox, oy)
              then raise EarlyClip
              else ()
          end));
        
        (* if everything is clear with no exn, then ok *)
        false
        ) handle EarlyClip => true

end

