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

  fun statetos s = String.concat (map tostring (M.history s))

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

  val GRAPHIC_SIZE = 1024
  val TABLE_SIZE = 1024.0
  val CELL_WIDTH = TABLE_SIZE / real modulus

  fun makesvg (filename : string, chain : M.chain) =
      let
          val f = TextIO.openOut filename
          fun fprint s = TextIO.output (f, s)
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
          val maxprobt = ref ("?", "?")
          val () = Array.app (fn (_, st, c) =>
                              Array.appi (fn (i, d) =>
                                          if d > !maxprob
                                          then (maxprob := d;
                                                maxprobt := (statetos st, 
                                                             tostring (M.fromint i)))
                                          else ()) c) cols
          val (st, sym) = !maxprobt
          val () = TextIO.output (TextIO.stdErr,
                                  "FYI max probability: " ^ rtos (!maxprob) ^ " @" ^
                                  st ^ "->" ^ sym ^ "\n")
      in
          fprint (TextSVG.svgheader { x = 0, y = 0, 
                                      width = GRAPHIC_SIZE,
                                      height = GRAPHIC_SIZE,
                                      generator = "nmarkov-svg.sml" });

          Array.appi (fn (col, (sym, state, rows)) =>
                      Array.appi (fn (row, p) =>
                                  let
                                      (* val () = print (rtos p ^ " / " ^ rtos (!maxprob)) *)
                                      val intensity = 1.0 - (p / !maxprob)
                                      (* Do square so it's not so white *)
                                      val intensity = intensity * intensity
                                      val c = Color.rgbf (intensity, intensity, intensity)
                                      val c = Color.tohexstring c
                                      (* val () = print (".. " ^ c ^ "\n") *)
                                  in
                                      fprint ("<rect x=\"" ^ rtos (real col * CELL_WIDTH) ^ 
                                              "\" y=\"" ^ rtos (real row * CELL_WIDTH) ^
                                              "\" width=\"" ^ rtos CELL_WIDTH ^
                                              "\" height=\"" ^ rtos CELL_WIDTH ^
                                              "\" fill=\"#" ^ c ^ "\" />\n")
                                  end) rows) cols;

          (* XXX improve by making hierarchical. *)
          Array.appi (fn (i, (syms, _, _)) =>
           fprint (TextSVG.svgtext { x = real i * CELL_WIDTH + (0.3 * CELL_WIDTH), 
                                     y = ~0.1 * CELL_WIDTH,
                                     face = "Franklin Gothic Medium",
                                     size = 0.6 * CELL_WIDTH,
                                     text = [("#000000", 
                                              String.concat
                                              (map tostring syms))] }))
           cols;
                      

          Util.for 0 (M.radix - 1)
          (fn i =>
           fprint (TextSVG.svgtext { x = ~0.5 * CELL_WIDTH, 
                                     y = real i * CELL_WIDTH + (0.8 * CELL_WIDTH),
                                     face = "Franklin Gothic Medium",
                                     size = 0.6 * CELL_WIDTH,
                                     text = [("#000000", tostring (M.fromint i))] })
           );

(*
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
          fprint (TextSVG.svgfooter ());
          TextIO.closeOut f
      end
end