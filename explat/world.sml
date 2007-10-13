
structure World :> WORLD =
struct
  open Tile

  datatype layer = FOREGROUND | BACKGROUND

  exception World of string

  (* XXX stub implementation: *)
  val OPENW = 150
  val OPENH = 150

  val world = { mask = Array.array(OPENW * OPENH, MEMPTY),
                fore = Array.array(OPENW * OPENH, Tile.fromword 0w0),
                back = Array.array(OPENW * OPENH, Tile.fromword 0w0) }

  fun maskat (x, y) = 
    if x < OPENW andalso x >= 0 andalso
       y < OPENH andalso y >= 0
    then Array.sub(#mask world, y * OPENW + x) 
    else MSOLID

  fun tileat (layer, x, y) = 
    if x < OPENW andalso x >= 0 andalso
       y < OPENH andalso y >= 0
    then Array.sub((case layer of
                        BACKGROUND => #back world
                      | FOREGROUND => #fore world), 
                   y * OPENW + x)
    else 
        (case layer of
             BACKGROUND => Tile.fromword 0w1
           | FOREGROUND => Tile.fromword 0w0)
                 
  fun setmask (x, y) m = 
      if x < OPENW andalso x >= 0 andalso
         y < OPENH andalso y >= 0
      then
          Array.update(#mask world, y * OPENW + x, m)
      else () (* ignore updates outside of open rectangle *)

  fun settile (layer, x, y) t = 
      if x < OPENW andalso x >= 0 andalso
         y < OPENH andalso y >= 0
      then
          Array.update((case layer of
                            BACKGROUND => #back world
                          | FOREGROUND => #fore world), 
                       y * OPENW + x, t)
      else () (* ignore updates outside of open rectangle *)

  fun maskf MEMPTY = "e"
    | maskf MSOLID = "s"
    | maskf (MRAMP LM) = "lm"
    | maskf (MRAMP MH) = "mh"
    | maskf _ = raise World "maskf"

  fun fmask "s" = MSOLID
    | fmask "lm" = MRAMP LM
    | fmask "mh" = MRAMP MH
    | fmask _ = MEMPTY

  val MASKFILE = "world.0.mask"
  val BGFILE = "world.0.bg"
  val FGFILE = "world.0.fg"

  fun save () =
      let 
          val fm = TextIO.openOut MASKFILE
          val ff = TextIO.openOut FGFILE
          val fb = TextIO.openOut BGFILE
      in
          Util.for 0 (OPENH - 1)
          (fn y =>
           (Util.for 0 (OPENW - 1)
            (fn x =>
             let in
                 TextIO.output(fb, Word32.toString (Tile.toword (tileat (BACKGROUND, x, y))) ^ " ");
                 TextIO.output(ff, Word32.toString (Tile.toword (tileat (FOREGROUND, x, y))) ^ " ");
                 TextIO.output(fm, maskf (maskat (x, y)) ^ " ")
             end);
            TextIO.output(ff, "\n");
            TextIO.output(fb, "\n");
            TextIO.output(fm, "\n")
            ));
          app TextIO.closeOut [fm, ff, fb]
      end

  exception Bad
  (* initialize *)
  val () = 
      let
          val f = StringUtil.readfile MASKFILE
          val l = Vector.fromList (String.tokens (StringUtil.ischar #"\n") f)
          val c = Vector.map (fn s => Vector.fromList 
                              (String.tokens (StringUtil.ischar #" ") s)) l
          val () = 
              Util.for 0 (OPENH - 1)
              (fn y =>
               (Util.for 0 (OPENW - 1)
                (fn x =>
                 setmask (x, y) (fmask (Vector.sub(Vector.sub(c, y), x)))
                 )))

          fun readlayer layer file =
              let
                  val f = StringUtil.readfile file
                  val l = Vector.fromList (String.tokens (StringUtil.ischar #"\n") f)
                  val c = Vector.map (fn s => Vector.fromList
                                      (String.tokens (StringUtil.ischar #" ") s)) l
              in
                  Util.for 0 (OPENH - 1)
                  (fn y =>
                   (Util.for 0 (OPENW - 1)
                    (fn x =>
                     settile (layer, x, y) (case Word32.fromString (Vector.sub(Vector.sub(c, y), x)) of
                                                 NONE => raise Bad
                                               | SOME w => Tile.fromword w)
                     )))
              end

          val () = readlayer BACKGROUND BGFILE
          val () = readlayer FOREGROUND FGFILE

      in
          ()
      end handle _ =>
          let in
              print "No saved world, so using default.\n";
              print "XXX I set masks, but not tiles. Enjoy invisible floors\n";
              Util.for 0 (OPENW - 1) (fn x => setmask (x, OPENH - 1) MSOLID);
              Util.for 4 (OPENW - 1) (fn x => 
                                      let in
                                          setmask(x, OPENH - 1 - (x div 2))
                                          (MRAMP (if x mod 2 = 0
                                                  then LM
                                                  else MH));
                                          if x > 12 andalso x mod 2 = 0
                                          then setmask(x, OPENH - (x div 2)) MSOLID
                                          else ()
                                      end);

              Util.for 0 (Int.min (OPENW, OPENH) - 1) 
              (fn x => 
               if x mod 3 = 0 
               then setmask (x, OPENH - 1 - x) MSOLID
               else ())
          end

(*
  local val seed = ref (0w1234567 : Word32.word)
  in
    fun rbool () = 
      let in
        seed := !seed * 0wxDEADBEEF;
        seed := !seed + 0w12345;
        seed := Word32.orb(Word32.<<(!seed, 0w13),
                           Word32.>>(!seed, 0w32 - 0w13));
        seed := Word32.xorb(0wx2778844F, !seed);
        Word32.andb(!seed, 0w1) = 0w0
      end
  end

  val () = Util.for 0 (OPENW * OPENH - 1)
    (fn i =>
     if rbool () andalso rbool () andalso rbool ()
     then Array.update(world, i, 
                       case (rbool (), rbool ()) of 
                         (true, true) => MRAMP LM
                       | (true, _) => MRAMP MH
                       | _ => MSOLID)
     else ())
*)

end