
structure Tile :> TILE =
struct

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

  (* need to implement this somehow.. *)
  type tile = Word32.word

  val TILEW = 16
  val TILEH = 16
  val TILEBITSW = 0w4
  val TILEBITSH = 0w4
  val MASKW = 0w15 : Word32.word
  val MASKH = 0w15 : Word32.word


  fun clipmask MEMPTY _ = false
    | clipmask MSOLID _ = true
    | clipmask (MRAMP LM) (x, y) = y >= (8 + (7 - x div 2))
    | clipmask (MRAMP MH) (x, y) = y >= (7 - x div 2)
    | clipmask (MRAMP HM) (x, y) = y >= x div 2
    | clipmask (MRAMP ML) (x, y) = y >= (8 + x div 2)
    | clipmask (MCEIL LM) (x, y) = y < (8 + (7 - x div 2))
    | clipmask (MCEIL MH) (x, y) = y < (7 - x div 2)
    | clipmask (MCEIL HM) (x, y) = y < x div 2
    | clipmask (MCEIL ML) (x, y) = y < (8 + x div 2)

    | clipmask (MLEFT HM) (x, y) = x < (8 + (7 - y div 2))
    | clipmask (MLEFT ML) (x, y) = x < (7 - y div 2)
    | clipmask (MLEFT LM) (x, y) = x < y div 2
    | clipmask (MLEFT MH) (x, y) = x < (8 + y div 2)


    | clipmask (MRIGHT LM) (x, y) = x >= (8 + (7 - y div 2))
    | clipmask (MRIGHT MH) (x, y) = x >= (7 - y div 2)
    | clipmask (MRIGHT HM) (x, y) = x >= y div 2
    | clipmask (MRIGHT ML) (x, y) = x >= (8 + y div 2)

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
  val solid = requireimage "solid.png"
  val error = requireimage "error_frame.png"

  val ramp_lm = requireimage "rampup1.png"
  val ramp_mh = requireimage "rampup2.png"
  val ramp_hm = requireimage "rampdown1.png"
  val ramp_ml = requireimage "rampdown2.png"

  val ceil_hm = requireimage "ceildown1.png"
  val ceil_ml = requireimage "ceildown2.png"
  val ceil_lm = requireimage "ceilup1.png"
  val ceil_mh = requireimage "ceilup2.png"

  val left_hm = requireimage "left_hm.png"
  val left_ml = requireimage "left_ml.png"
  val left_lm = requireimage "left_lm.png"
  val left_mh = requireimage "left_mh.png"

  val right_hm = requireimage "right_hm.png"
  val right_ml = requireimage "right_ml.png"
  val right_lm = requireimage "right_lm.png"
  val right_mh = requireimage "right_mh.png"

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
    | tilefor (MCEIL HM) = ceil_hm
    | tilefor (MCEIL ML) = ceil_ml
    | tilefor (MCEIL LM) = ceil_lm
    | tilefor (MCEIL MH) = ceil_mh
    | tilefor (MLEFT HM) = left_hm
    | tilefor (MLEFT ML) = left_ml
    | tilefor (MLEFT LM) = left_lm
    | tilefor (MLEFT MH) = left_mh
    | tilefor (MRIGHT HM) = right_hm
    | tilefor (MRIGHT ML) = right_ml
    | tilefor (MRIGHT LM) = right_lm
    | tilefor (MRIGHT MH) = right_mh

    | tilefor _ = error

  (* assumes power of two *)
  val NSEEDS = 16
  val seeds = 
      Vector.fromList 
      [0wxD76AA478 : Word32.word,
       0wxE8C7B756,
       0wx242070DB,
       0wxC1BDCEEE,
       0wxF57C0FAF,
       0wx4787C62A,
       0wxA8304613,
       0wxFD469501,
       0wx698098D8,
       0wx8B44F7AF,
       0wxFFFF5BB1,
       0wx895CD7BE,
       0wx6B901122,
       0wxFD987193,
       0wxA679438E,
       0wx49B40821]

  (* should do something not ad hoc here... *)
  fun animate (n, t, wx, wy) =
      (* star *)
      if t >= 16 andalso t <= 18
      then 16 + (((n div 8) + (t - 16)) mod 3)
      else 
          (* flower *)
          if t = 70 andalso (((n div 4) + wx) mod 3 = 1)
          then 71
          else 
              (* bubble *)
              if t = 64
              then (case ((n div 7) + wx + wy) mod 9 of
                        0 => 64
                      | 1 => 65
                      | 2 => 66
                      | _ => 4 (* black nothing *))
              else
                  (* water surface *)
                  if t = 82
                  then 82 + ((n div 5) mod 4)
                  else t

  fun drawmask (MEMPTY, surf, x, y) = ()
    | drawmask (m, surf, x, y) =
      SDL.blitall (tilefor m, surf, x, y)


  fun randomize (w1, w2, w3) = 
      let
          val xx = w1
          val yy = w2 + Word32.andb(xx, 0w3)
          val zz = Vector.sub(seeds, 
                              Word32.toInt(Word32.andb(Word32.fromInt (NSEEDS - 1),
                                                       yy)))
          (* val () = print (" - " ^ Word32.toString zz ^ "\n") *)
          val h = Word32.xorb(xx * yy, 0wxDEADBEEF) + (zz * 0w31337)
      in
          h
      end

  fun drawat (_, 0w0, surf, x, y, _, _) = ()
    | drawat (time, 0w33, surf, x, y, wx, wy) =
      let
          val n = randomize (Word32.fromInt wx,
                             Word32.fromInt wy,
                             0w33)
          val u = Word32.andb(Word32.>> (n, 0w7), 0w15)
          val t = 
              case u of
                  0w0 => 0w35
                | 0w1 => 0w36
                | 0w2 => 0w51
                | 0w3 => 0w35
                | 0w4 => 0w35
                | 0w5 => 0w35
                | _ => 0w52
      in
          drawat (time, t, surf, x, y, wx, wy)
      end

    (* open problem: draw moving stars! *)
    (* stars (stationary) *)
    | drawat (time, 0w32, surf, x, y, wx, wy) =
      let
          (* stars are drawn at a fixed location
             on the screen, so figure out what
             patch we're in and draw a whole tile's worth *)
          val xx = Word32.fromInt wx
          val yy = Word32.fromInt wy
          val h = Word32.xorb(xx, 0wxDEADBEEF) + (yy * 0w31337)
          val n = Word32.toInt (Word32.andb(h, 0w7))

          fun star (0, _) = ()
            | star (n, h) =
              let
                  (* assumes tilebits * 3 < 32 *)
                  val px = Word32.andb(Word32.>>(h, TILEBITSW),
                                       MASKW)
                  val py = Word32.andb(Word32.>>(h, 0w1 + (0w2 * TILEBITSH)),
                                       MASKH)
                      
                  val lightc = Word8.fromInt time * Word8.fromInt n 
                  val c = SDL.color (lightc, lightc, 0wx22, 0wxFF)

                  val tx = x + Word32.toInt px
                  val ty = y + Word32.toInt py
              in
                  if tx >= 0 andalso ty >= 0
                     andalso tx < SDL.surface_width surf
                     andalso ty < SDL.surface_height surf
                  then SDL.drawpixel(surf, tx, ty, c)
                  else ();

                  star (n - 1, 
                        Word32.xorb(Word32.fromInt n * (h + 0w1234567),
                                    Word32.orb(Word32.<<(h, 0w11),
                                               Word32.>>(h, 0w32 - 0w11))))
              end
              
      in
          star (n, h)
      end

    (* PERF probably other solid colors can be done more efficiently *)
    | drawat (n, t, surf, x, y, wx, wy) =
      let 
          val t = Word32.toInt t
          val t = animate (n, t, wx, wy)
      in
          SDL.blit (tileset, 
                    (t mod SETW) * TILEW,
                    (t div SETW) * TILEH,
                    TILEW, TILEH,
                    surf,
                    x, y)
      end

  fun draw (t, surf, x, y, wx, wy) = drawat(Animate.now (), t, surf, x, y, wx, wy)

  fun toword x = x
  fun fromword x = x (* XXX check bounds *)

end