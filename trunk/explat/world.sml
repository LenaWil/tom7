
structure World :> WORLD =
struct
  open Tile

  exception World of string

  (* XXX stub implementation: *)
  val OPENW = 150
  val OPENH = 150

  val world = Array.array(OPENW * OPENH, MEMPTY)


  fun maskat (x, y) = 
    if x < OPENW andalso x >= 0 andalso
       y < OPENH andalso y >= 0
    then Array.sub(world, y * OPENW + x) 
    else MSOLID

  fun bgtileat _ = raise World "tileat unimplemented"
  fun fgtileat _ = raise World "tileat unimplemented"

  fun setworld (x, y) m = 
      if x < OPENW andalso x >= 0 andalso
         y < OPENH andalso y >= 0
      then
          Array.update(world, y * OPENW + x, m)
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

  val WORLDFILE = "world.0"

  fun save () =
      let 
          val f = TextIO.openOut WORLDFILE
      in
          Util.for 0 (OPENH - 1)
          (fn y =>
           (Util.for 0 (OPENW - 1)
            (fn x =>
             TextIO.output(f, maskf (maskat (x, y)) ^ " "));
            TextIO.output(f, "\n")
            ));
          TextIO.closeOut f
      end

  (* initialize *)
  val () = 
      let
          val f = StringUtil.readfile WORLDFILE
          val l = Vector.fromList (String.tokens (StringUtil.ischar #"\n") f)
          val c = Vector.map (fn s => Vector.fromList 
                              (String.tokens (StringUtil.ischar #" ") s)) l
      in
          Util.for 0 (OPENH - 1)
          (fn y =>
           (Util.for 0 (OPENW - 1)
            (fn x =>
             setworld (x, y) (fmask (Vector.sub(Vector.sub(c, y), x)))
             )))
      end handle _ =>
          let in
              print "No saved world, so using default.\n";
              Util.for 0 (OPENW - 1) (fn x => setworld (x, OPENH - 1) MSOLID);
              Util.for 4 (OPENW - 1) (fn x => 
                                      let in
                                          setworld(x, OPENH - 1 - (x div 2))
                                          (MRAMP (if x mod 2 = 0
                                                  then LM
                                                  else MH));
                                          if x > 12 andalso x mod 2 = 0
                                          then setworld(x, OPENH - (x div 2)) MSOLID
                                          else ()
                                      end);

              Util.for 0 (Int.min (OPENW, OPENH) - 1) 
              (fn x => 
               if x mod 3 = 0 
               then setworld (x, OPENH - 1 - x) MSOLID
               else ())
          end

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
(*
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