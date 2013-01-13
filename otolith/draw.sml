
structure Draw :> DRAW =
struct

  open Constants

  val rc = ARCFOUR.initstring "draw"

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
            fun byte () = Word32.fromInt (Word8.toInt (ARCFOUR.byte rc))
            (* Very low level color noise *)
            val r = Word32.andb (byte (), 0w15)
            val g = Word32.andb (byte (), 0w15)
            val b = Word32.andb (byte (), 0w31)
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
            fun byte () = Word32.fromInt (Word8.toInt (ARCFOUR.byte rc))
            (* Very low level color noise *)
            val r = Word32.andb (byte (), 0w31)
            val g = Word32.andb (byte (), 0w31)
            val b = Word32.andb (byte (), 0w63)
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

        fun byte () = ARCFOUR.byte rc
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

end