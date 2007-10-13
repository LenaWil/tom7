
structure Tile :> TILE =
struct

  exception Tile of string

  (* the mask tells us where things can walk *)
  datatype slope = LM | MH | HM | ML
  datatype diag = NW | NE | SW | SE
  datatype mask = 
      MEMPTY 
    | MSOLID 
    | MRAMP of slope (* | MCEIL of slope *)
    | MDIAG of diag (* corner that is filled in *)

  (* need to implement this somehow.. *)
  type tile = Word32.word

  val TILEW = 16
  val TILEH = 16

  fun clipmask MEMPTY _ = false
    | clipmask MSOLID _ = true
    | clipmask (MRAMP LM) (x, y) = y >= (8 + (7 - x div 2))
    | clipmask (MRAMP MH) (x, y) = y >= (7 - x div 2)
    | clipmask (MRAMP HM) (x, y) = y >= x div 2
    | clipmask (MRAMP ML) (x, y) = y >= (8 + x div 2)
    | clipmask (MDIAG SW) (x, y)  = y >= x
    | clipmask (MDIAG SE) (x, y)  = y >= (15 - x)
    | clipmask (MDIAG NE) (x, y)  = y < x
    | clipmask (MDIAG NW) (x, y)  = y < (15 - x)
    | clipmask _ _ = false (* FIXME! *)

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
  val ramp_lm = requireimage "rampup1.png"
  val ramp_mh = requireimage "rampup2.png"
  val ramp_hm = requireimage "rampdown1.png"
  val ramp_ml = requireimage "rampdown2.png"
  val solid = requireimage "solid.png"
  val error = requireimage "error_frame.png"

  val diag_ne = requireimage "diag_ne.png"
  val diag_nw = requireimage "diag_nw.png"
  val diag_sw = requireimage "diag_sw.png"
  val diag_se = requireimage "diag_se.png"

  (* just drawing masks for now to test physics *)
  fun tilefor MSOLID = solid
    | tilefor (MRAMP LM) = ramp_lm
    | tilefor (MRAMP MH) = ramp_mh
    | tilefor (MRAMP HM) = ramp_hm
    | tilefor (MRAMP ML) = ramp_ml
    | tilefor (MDIAG NW) = diag_nw 
    | tilefor (MDIAG NE) = diag_ne
    | tilefor (MDIAG SW) = diag_sw
    | tilefor (MDIAG SE) = diag_se
    | tilefor _ = error

  (* should do something not ad hoc here... *)
  fun animate (n, t) =
      if t >= 16 andalso t <= 18
      then 16 + (((n div 8) + (t - 16)) mod 3)
      else 
          if t = 54 andalso ((t div 4) mod 3 = 1)
          then 55
          else t

  fun drawmask (MEMPTY, surf, x, y) = ()
    | drawmask (m, surf, x, y) =
      SDL.blitall (tilefor m, surf, x, y)

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