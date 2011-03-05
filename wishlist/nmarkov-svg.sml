(* Makes an SVG-format table (heatmap) from an N-Markov chain. *)
functor NMarkovSVG(structure M : NMARKOV
                   val tostring : M.symbol -> string) =
struct

  fun pow n 0 = 1
    | pow n k = pow n (k - 1) * n
  val modulus = pow M.radix M.n
  fun history s =
      let
          fun h 0 i = (i, nil)
            | h m i =
              let val (i, t) = h (m - 1) i
              in (i div M.radix, M.fromint (i mod M.radix) :: t)
              end
          val (_, l) = h M.n s
      in
          l
      end

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

  fun makesvg (chain : M.chain) =
      let
          (* Get normalized probabilities in (radix^n * radix) array. *)
          fun makecol n =
              let
                  val syms = history n
                  val state = M.state syms
              in
                  (syms, state, 
                   Array.tabulate (M.radix, 
                                   (fn i =>
                                    M.probability chain (state, M.fromint i))))
              end
              
          val cols = Array.tabulate (modulus, makecol)
              
          (* Maximum probability anywhere. *)
          val maxprob = ref 0.0
          val () = Array.app (fn (_, _, c) =>
                              Array.app (fn d =>
                                         if d > !maxprob
                                         then maxprob := d
                                         else ()) c) cols
          val () = print ("FYI max probability: " ^ rtos (!maxprob) ^ "\n")
      in
(*
          (* XXX compute actual size *)
          print (TextSVG.svgheader { x = 0, y = 0, 
                                     width = GRAPHIC_SIZE,
                                     height = GRAPHIC_SIZE,
                                     generator = "radial.sml" });

          (* Black background. *)
          print ("<rect x=\"-10\" y=\"-10\" width=\"" ^
                  Int.toString (GRAPHIC_SIZE + 20) ^ "\" height=\"" ^
                  Int.toString (GRAPHIC_SIZE + 20) ^ "\" style=\"fill:rgb(20,20,32)\" />\n");

          makerays 0;
          makecircles 1;

          print (TextSVG.svgtext { x = 5.0, y = 20.0,
                                   face = "Franklin Gothic Medium",
                                   size = 18.0,
                                   text = [("#FFFF9E", "Pac Tom Project")] });

          print (TextSVG.svgtext { x = 5.0, y = 38.0,
                                   face = "Franklin Gothic Medium",
                                   size = 16.0,
                                   text = [("#CCCCCC", datestring),
                                           ("#666666", " - "),
                                           ("#6297C9", "http://pac.tom7.org")] });

          Vector.app printpolyline paths;
          List.app print (!endcircles);
*)
          print (TextSVG.svgfooter ())
      end
end