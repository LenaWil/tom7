
structure Draw :> DRAW =
struct

  open Constants

  val rc = ARCFOUR.initstring "draw"
  fun byte () = ARCFOUR.byte rc

  local
      val orb = Word32.orb
      infix orb
  in
      fun mixcolor (r, g, b, a) =
          Word32.<< (a, 0w24) orb
          Word32.<< (r, 0w16) orb
          Word32.<< (g, 0w8) orb
          b
  end

  local

      fun pair_swap (x, y) = (y, x)
      fun pair_map f (x, y) = (f x, f y)
      fun pair_map2 f (x1, y1) (x2, y2) = (f (x1, x2), f (y1, y2))

      fun build ((x0, y0), (x1, _), (dx, dy), (stepx, stepy), post) =
        let val frac0 = dy - Int.quot (dx, 2)
            fun step (x0, y0, frac) =
              if x0 = x1
              then NONE
              else
                  let val (y0, frac) = if frac >= 0
                                       then (y0 + stepy, frac - dx)
                                       else (y0, frac)
                      val x0 = x0 + stepx
                      val frac = frac + dy
                  in SOME ((x0, y0, frac), post (x0, y0))
                  end
        in ({step = step, seed = (x0, y0, frac0)}, post (x0, y0))
        end

      fun line p0 p1 =
        let
            val d = pair_map2 op- p1 p0
            fun abs c = if c < 0 then (~c, ~1) else (c, 1)
            val ((dx', stepx), (dy', stepy)) = pair_map abs d
            val step = (stepx, stepy)
            val d'' as (dx'', dy'') = pair_map (fn n => n * 2) (dx', dy')

            val cvt = (fn x => x)
            val seed =
                if dx'' > dy''
                then (p0, p1, d'', step, cvt)
                else (pair_swap p0, pair_swap p1, pair_swap d'', pair_swap step,
                      pair_swap)
        in build seed
        end

  in
      fun drawline (pixels, x0, y0, x1, y1, c : Word32.word) =
          let
              (* PERF bounds check. *)
              (* Should allow alpha blending? *)
              fun dp (x, y) = Array.update (pixels, y * WIDTH + x, c)

              fun clippixel (x, y) =
                  if x < 0 orelse y < 0
                     orelse x >= WIDTH
                     orelse y >= HEIGHT
                  then ()
                  else dp (x, y)

              fun app (p0, p1) =
                  let
                      val ({step, seed}, v) = line p0 p1
                      fun loop seed =
                          case step seed of
                              NONE => ()
                            | SOME (seed', v) => (clippixel v; loop seed')
                  in
                      clippixel v;
                      loop seed
                  end
          in
              (* PERF could pre-clip, or stop as soon as we get off screen? *)
              app ((x0, y0), (x1, y1))
          end

      fun drawlinewith (pixels, x0, y0, x1, y1, segment : Word32.word vector) =
          let

              (* PERF bounds check. *)
              (* Should allow alpha blending? *)
              fun dp (x, y, c) = Array.update (pixels, y * WIDTH + x, c)

              fun clippixel (x, y, i) =
                  (* PERF bounds check *)
                  case Vector.sub(segment, i) of
                      0w0 => ()
                    | c =>
                        if x < 0 orelse y < 0
                           orelse x >= WIDTH
                           orelse y >= HEIGHT
                        then ()
                        else dp (x, y, c)

              fun app (p0, p1) =
                  let
                      val ({step, seed}, (xstart, ystart)) = line p0 p1
                      fun loop (i, seed) =
                          case step seed of
                              NONE => ()
                            | SOME (seed', (x, y)) =>
                               let
                                   val i = i + 1
                                   val i = if i >= Vector.length segment
                                           then i - Vector.length segment
                                           else i
                               in
                                   clippixel (x, y, i);
                                   loop (i, seed')
                               end
                  in
                      clippixel (xstart, ystart, 0);
                      loop (0, seed)
                  end
          in
              (* PERF could pre-clip, or stop as soon as we get off screen? *)
              app ((x0, y0), (x1, y1))
          end

  end

  fun drawcircle (pixels, x0, y0, radius, c) =
      let
          (* PERF bounds check. *)
          (* Should allow alpha blending? *)
          fun dp (x, y) = Array.update (pixels, y * WIDTH + x, c)

          fun clippixel (x, y) =
              if x < 0 orelse y < 0
                 orelse x >= WIDTH
                 orelse y >= HEIGHT
              then ()
              else dp (x, y)

          val f = 1 - radius
          val ddF_x = 1
          val ddF_y = ~2 * radius
          val x = 0
          val y = radius

          val () = clippixel(x0, y0 + radius)
          val () = clippixel(x0, y0 - radius)
          val () = clippixel(x0 + radius, y0)
          val () = clippixel(x0 - radius, y0)

          fun loop (x, y, f, ddF_x, ddF_y) =
              if x < y
              then
                  let
                      val (y, f, ddF_y) =
                          if f >= 0
                          then (y - 1, 2 + f + ddF_y, 2 + ddF_y)
                          else (y, f, ddF_y)
                      val x = x + 1
                      val ddF_x = ddF_x + 2
                      val f = ddF_x + f
                  in
                      clippixel(x0 + x, y0 + y);
                      clippixel(x0 - x, y0 + y);
                      clippixel(x0 + x, y0 - y);
                      clippixel(x0 - x, y0 - y);
                      clippixel(x0 + y, y0 + x);
                      clippixel(x0 - y, y0 + x);
                      clippixel(x0 + y, y0 - x);
                      clippixel(x0 - y, y0 - x);
                      loop (x, y, f, ddF_x, ddF_y)
                  end
              else ()
      in
          loop (x, y, f, ddF_x, ddF_y)
      end

  fun randomize pixels =
      Util.for 0 (HEIGHT - 1)
      (fn y =>
       Util.for 0 (WIDTH - 1)
       (fn x =>
        let
            fun byte32 () = Word32.fromInt (Word8.toInt (byte ()))
            (* Very low level color noise *)
            val r = Word32.andb (byte32 (), 0w15)
            val g = Word32.andb (byte32 (), 0w15)
            val b = Word32.andb (byte32 (), 0w31)
            val a = 0wxFF : Word32.word
            val color = mixcolor (r, g, b, a)
        in
            Array.update(pixels, y * WIDTH + x, color)
        end
        ))

  fun randomize_loud pixels =
      Util.for 0 (HEIGHT - 1)
      (fn y =>
       Util.for 0 (WIDTH - 1)
       (fn x =>
        let
            fun byte32 () = Word32.fromInt (Word8.toInt (byte ()))
            (* Very low level color noise *)
            val r = Word32.andb (byte32 (), 0w31)
            val g = Word32.andb (byte32 (), 0w31)
            val b = Word32.andb (byte32 (), 0w63)
            val a = 0wxFF : Word32.word
            val color = mixcolor (r, g, b, a)
        in
            Array.update(pixels, y * WIDTH + x, color)
        end
        ))

  fun scanline_postfilter pixels =
    let val ro = ref 0
        val go = ref 0
        val bo = ref 0

        fun modify p =
            case Word8.andb (byte (), 0wxFF) of
                0w0 => if !p < 3
                       then p := !p + 1
                       else ()
              | 0w1 => if !p > 0
                       then p := !p - 1
                       else ()
              | 0w2 => if !p > 0
                       then p := !p - 1
                       else ()
              | _ => ()
    in
        Util.for 0 (HEIGHT - 1)
        (fn y =>
         let in
             modify ro;
             modify go;
             modify bo;

             if !ro <> 0 orelse !go <> 0 orelse !bo <> 0
             then
                 Util.for 0 (WIDTH - 1)
                 (fn x =>
                  let val x = (WIDTH - 1) - x
                      fun getpixel p =
                          if p < 0 then 0w0
                          else Array.sub(pixels, y * WIDTH + p)

                      val r = Word32.andb(getpixel (x - !ro), 0wxFF0000)
                      val g = Word32.andb(getpixel (x - !go), 0wxFF00)
                      val b = Word32.andb(getpixel (x - !bo), 0wxFF)
                  in
                      Array.update(pixels, y * WIDTH + x,
                                   Word32.orb(0wxFF000000,
                                              Word32.orb(r,
                                                         Word32.orb(g, b))))
                  end)
             else ()
         end)
    end

  fun mixpixel_postfilter pctfrac mixfrac (pixels : Word32.word Array.array) =
    let
        (* Test if a random byte is less than this to decide whether
           we perform the operation. *)
        val pctbyte = Word8.fromInt (Real.trunc (pctfrac * 255.0))
        fun doit () = byte () < pctbyte

        val ommixfrac = 1.0 - mixfrac

        fun modify p =
            case Word8.andb (byte (), 0wxFF) of
                0w0 => if !p < 3
                       then p := !p + 1
                       else ()
              | 0w1 => if !p > 0
                       then p := !p - 1
                       else ()
              | 0w2 => if !p > 0
                       then p := !p - 1
                       else ()
              | _ => ()
    in
        Util.for 0 (HEIGHT - 1)
        (fn y =>
         Util.for 0 (WIDTH - 1)
         (fn x =>
          let
              val thispixel = Array.sub(pixels, y * WIDTH + x)
              fun getpixel (xx, yy) =
                  if xx < 0 orelse xx >= WIDTH orelse
                     yy < 0 orelse yy >= HEIGHT
                  then 0w0
                  (* PERF bounds *)
                  else Array.sub(pixels, yy * WIDTH + xx)

              fun setpixel (xx, yy, p) =
                  if xx < 0 orelse xx >= WIDTH orelse
                     yy < 0 orelse yy >= HEIGHT
                  then ()
                  (* PERF bounds *)
                  else Array.update(pixels, yy * WIDTH + xx, p)

              (* Return one of the four neighboring pixels at random. *)
              fun getdir () =
                  case Word8.andb (byte (), 0w3) of
                      0w0 => (x + 1, y)
                    | 0w1 => (x, y + 1)
                    | 0w2 => (x - 1, y)
                    | _ => (x, y - 1)

              (* PERF: This was MUCH faster when just swapping the channels;
                 still looked cool. *)
              fun mixchannel (shift, mask, thispixel, thatpixel) =
                  let
                      val || = Word32.orb
                      val && = Word32.andb
                      val ~~ = Word32.notb
                      val >> = Word32.>>
                      val << = Word32.<<
                      infix || && << >>

                      val bthis = (thispixel && mask) >> shift
                      val bthat = (thatpixel && mask) >> shift

                      (* now mix this and that bytes. *)
                      (* PERF: do this without floating point! *)
                      (* real in [0, 255] *)
                      val fthis = real (Word32.toInt bthis)
                      val fthat = real (Word32.toInt bthat)

                      val mixedthis = fthat * mixfrac + fthis * ommixfrac
                      val mixedthat = fthis * mixfrac + fthat * ommixfrac

                      val bthis = Word32.fromInt (Real.trunc mixedthis)
                      val bthat = Word32.fromInt (Real.trunc mixedthat)

                      (* new full pixels *)
                      val nthis = (thispixel && ~~mask) || (bthis << shift)
                      val nthat = (thatpixel && ~~mask) || (bthat << shift)
                  in
                      (nthis, nthat)
                  end

              fun onechannel (shift, mask, thispixel) =
                if doit ()
                then
                  let val (xx, yy) = getdir ()
                      val thatpixel = getpixel (xx, yy)
                      val (thispixel, thatpixel) =
                          mixchannel (shift, mask, thispixel, thatpixel)
                  in
                      setpixel (xx, yy, thatpixel);
                      thispixel
                  end
                else thispixel

              val thispixel = onechannel (0w0, 0wxFF, thispixel)
              val thispixel = onechannel (0w8, 0wxFF00, thispixel)
              val thispixel = onechannel (0w16, 0wxFF0000, thispixel)
          in
              Array.update (pixels, y * WIDTH + x, thispixel)
          end))
    end

end