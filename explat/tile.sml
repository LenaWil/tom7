
structure Tile :> TILE =
struct

  exception Tile of string

  (* the mask tells us where things can walk *)
  datatype slope = LM | MH | HM | ML
  datatype mask = MEMPTY | MSOLID | MRAMP of slope (* | MCEIL of slope *)

  (* need to implement this somehow.. *)
  type tile = Word32.word

  val TILEW = 16
  val TILEH = 16

  fun clipmask MEMPTY _ = false
    | clipmask MSOLID _ = true
    | clipmask (MRAMP LM) (x, y) = y >= (8 + (7 - x div 2))
    | clipmask (MRAMP MH) (x, y) = y >= (7 - x div 2)
    | clipmask (MRAMP _) _ = false (* FIXME! *)

  fun requireimage s =
      let val s = "testgraphics/" ^ s
      in
          case SDL.Image.load s of
              NONE => (print ("couldn't open " ^ s ^ "\n");
                       raise Tile "couldn't find graphics")
            | SOME p => p
      end
  
  val SETW = 16
  val tileset = requireimage "tiles.png"

  (* should do something not ad hoc here... *)
  fun animate (n, t) =
      if t >= 16 andalso t <= 18
      then 16 + ((n + (t - 16)) mod 3)
      else t

  fun draw (_, 0w0, surf, x, y) = ()
    (* PERF probably other solid colors can be done more efficiently *)
    | draw (n, t, surf, x, y) =
      let 
          val t = Word32.toInt t
          val t = animate (n, t)
      in
          SDL.blit (tileset, 
                    (t mod SETW) * TILEW,
                    (t div SETW) * TILEH,
                    TILEW, TILEH,
                    surf,
                    x, y)
      end

  fun toword x = x
  fun fromword x = x (* XXX check bounds *)

end