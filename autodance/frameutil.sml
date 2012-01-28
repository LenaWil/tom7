
structure FrameUtil =
struct

  exception FrameUtil of string
  structure FC = FrameCache

  type frame = Word8.word Array.array
  fun blackframe (width, height) : frame =
    Array.tabulate (width * height * 4,
                    fn i =>
                    if i mod 4 = 3 then 0wxFF
                    else 0w0)

  fun saveframe (f, w, h, a) =
      if PNGsave.save (f, w, h, a)
      then print ("Wrote " ^ f ^ "\n")
      else raise FrameUtil ("Couldn't write " ^ f)

  fun blendweightedframes _ nil = raise FrameUtil "Can't blend 0 frames"
    | blendweightedframes (w, h) frames =
      let
          val aa = Array.array (w * h * 4, 0w0)
          val len = length frames
          val () = print ("Weighted blend of " ^ Int.toString len ^ " frame(s)\n")
          val denom = foldr (fn ((wt, _), sum) => wt + sum) 0.0 frames

          (* Get the color component, merged, from all the frames. *)
          fun get (x, y, i) =
              let val total =
                  foldr (fn ((wt, a), acc) => acc +
                         wt *
                         real (Word8.toInt (Array.sub (a, (w * y + x) * 4 + i)))) 0.0 frames
                  val avg = total / denom
              in
                  Word8.fromInt (Real.round avg)
              end

      in
          Util.for 0 (h - 1)
          (fn y =>
           Util.for 0 (w - 1)
           (fn x =>
            let val r = get (x, y, 0)
                val g = get (x, y, 1)
                val b = get (x, y, 2)
                val a = 0w255
            in
                Array.update(aa, (w * y + x) * 4 + 0, r);
                Array.update(aa, (w * y + x) * 4 + 1, g);
                Array.update(aa, (w * y + x) * 4 + 2, b);
                Array.update(aa, (w * y + x) * 4 + 3, a)
            end
            ));
          aa
      end

  fun blendframes (w, h) l = blendweightedframes (w, h) (map (fn a => (1.0, a)) l)

  (* XXX if num = 1? *)
  fun sampletime (cache, num, t : real) : frame =
      (* naive, bilinear. We can do much better... *)
      let
          val fracframe = t * real (num - 2) (* ??? *)
          val base = Real.trunc fracframe
          val blend = fracframe - real base
      in
          blendweightedframes (FC.width cache, FC.height cache)
                               [(1.0 - blend, FC.get cache base),
                                (blend, FC.get cache (base + 1))]
      end

  (* Sample the interval. We include all frames that fall between t0 and t1,
     cosine smoothed to give the most weight to the center frame. *)
  fun sampleinterval (cache, num, t0, t1) : frame =
      let

          val tcenter = (t0 + t1) / 2.0

          (* The number of actual frames on each side of the
             center that we must consider, not including the center
             itself. Might be zero. *)
          local
              val f0 = t0 * real (num - 1)
              val f1 = t1 * real (num - 1)
          in
              val nhalf = Real.floor ((f1 - f0) / 2.0)
              val () = print ("nhalf: " ^ Int.toString nhalf ^ "\n")
          end

          (* Amount of time that one frame takes up. *)
          val span = 1.0 / real (num - 1)

          (* First do pairwise linear interpolation to sample
             moments: *)
          val interpolated =
              (1.0, tcenter) ::
              List.concat
              (List.tabulate (nhalf,
                              fn i =>
                              let
                                  (* how far are we on this side? *)
                                  val frac = real i / real nhalf
                                  (* starts at 1.0 for frac=0.0,
                                     smoothly drops to 0.0 for frac=1.0 *)
                                  val weight = 0.5 * (1.0 + Math.cos (frac * Math.pi))

                                  (* Sample time, from center. Is this right? *)
                                  val offset = span * real (i + 1)
                              in
                                  [(weight, tcenter + offset),
                                   (weight, tcenter - offset)]
                              end))
      in
          (* PERF: Could sample in one pass. *)
          (* PERF: Frames appear multiple times in the list with
             different weights; could just sum them *)
          blendweightedframes (FC.width cache, FC.height cache)
          (map (fn (wt, time) => (wt, sampletime (cache, num, time))) interpolated)
      end

end
