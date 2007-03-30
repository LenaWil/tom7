
structure World =
struct
  open Tile

  (* XXX stub implementation: *)
  val OPENW = 150
  val OPENH = 150

  val world = Array.array(OPENW * OPENH, MEMPTY)
  (* XXX do we really want to trap subscript? *)
  fun maskat (x, y) = 
    Array.sub(world, y * OPENW + x) 
    handle Subscript => if y > 0 then MSOLID else MEMPTY

  fun setworld (x, y) m = Array.update(world, y * OPENW + x, m)
  val () = Util.for 0 (OPENW - 1) (fn x => setworld (x, OPENH - 1) MSOLID)
  val () = Util.for 4 (OPENW - 1) (fn x => setworld(x, OPENH - 1 - (x div 2)) 
                                   (MRAMP (if x mod 2 = 0
                                           then LM
                                           else MH)))
  val () = Util.for 0 (Int.min (OPENW, OPENH) - 1) 
    (fn x => 
     if x mod 3 = 0 
     then setworld (x, OPENH - 1 - x) MSOLID
     else ())

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
     then Array.update(world, i, MSOLID)
     else ())

end