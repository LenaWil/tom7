
structure Grid =
struct
  (* for power-days
  val RADIX = 60 * 24 *)
  val RADIX = 60

  exception Illegal
  val itos = Int.toString

  fun makecol n =
      let
          val lines = Script.linesfromfile ("possible-" ^ itos n ^
                                            "cup-60min-1player.txt")
          fun parse1 line =
              case map Int.fromString (String.fields (StringUtil.ischar #",") line) of
                  [SOME a] => SOME a
                | nil => NONE (* Allow blank lines *)
                | _ => raise Illegal
          val lines = List.mapPartial parse1 lines
          val lines = ListUtil.mapto (fn _ => n) lines
      in
          lines
      end

  val possible =
      List.concat (List.tabulate(8, fn x => makecol (x + 1)))

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

  fun go () =
      let
          val f = TextIO.openOut "solo-ncups.svg"
          fun fprint s = TextIO.output (f, s)

          val GRAPHIC_SIZE = 1024
          val LABEL_WIDTH = 64
          val LABEL_HEIGHT = 64
          val LABEL_GAP = 7

          val CELL_WIDTH = real GRAPHIC_SIZE / real (RADIX + 1)

          fun makegrid2x2 l =
              let
                  fun onecell (x, y) =
                      fprint ("<rect x=\"" ^ rtos (real x * CELL_WIDTH) ^
                              "\" y=\"" ^ rtos (real y * CELL_WIDTH) ^
                              "\" width=\"" ^ rtos CELL_WIDTH ^
                              "\" height=\"" ^ rtos CELL_WIDTH ^
                              "\" style=\"fill:#000\" />\n")
              in
                              app onecell l
              end

      in
          print ("There are " ^ Int.toString (length possible) ^ " possibilities\n");
          fprint (TextSVG.svgheader { x = 0, y = 0,
                                      width = GRAPHIC_SIZE + LABEL_WIDTH,
                                      height = GRAPHIC_SIZE + LABEL_HEIGHT,
                                      generator = "grid.sml" });

          (* Vertical grid lines *)
          Util.for 0 RADIX
          (fn i =>
           let val x = CELL_WIDTH * real i
           in
               fprint ("<polyline fill=\"none\" stroke=\"#AAA\" stroke-width=\"0.5\" " ^
                       "points=\""); (* " *)
               fprint (rtos x ^ "," ^ rtos 0.0 ^ " " ^
                       rtos x ^ "," ^ rtos (real GRAPHIC_SIZE));
               fprint ("\" />\n") (* " *)
           end);

          (* Horizontal grid lines *)
          Util.for 0 RADIX
          (fn i =>
           let val y = CELL_WIDTH * real i
           in
               fprint ("<polyline fill=\"none\" stroke=\"#AAA\" stroke-width=\"0.5\" " ^
                       "points=\""); (* " *)
               fprint (rtos 0.0 ^ "," ^ rtos y ^ " " ^
                       rtos (real GRAPHIC_SIZE) ^ "," ^ rtos y);
               fprint ("\" />\n") (* " *)
           end);

          (* Fill in the grid *)
          makegrid2x2 possible;

          (* Vertical labels, at right. *)
          Util.for 0 RADIX
          (fn i =>
           fprint (TextSVG.svgtext { x = CELL_WIDTH * real (RADIX + 1) + real LABEL_GAP,
                                     y = real i * CELL_WIDTH + (0.7 * CELL_WIDTH),
                                     face = "Franklin Gothic Medium",
                                     size = 0.6 * CELL_WIDTH,
                                     text = [("#000", Int.toString i)] } ^ "\n")
           );

          (* Horizontal labels, on bottom *)
          Util.for 0 RADIX
          (fn i =>
           fprint (TextSVG.svgtext { x = real i * CELL_WIDTH + (0.2 * CELL_WIDTH),
                                     y = CELL_WIDTH * real (RADIX + 1) + real LABEL_GAP * 1.5,
                                     face = "Franklin Gothic Medium",
                                     size = 0.6 * CELL_WIDTH,
                                     text = [("#000", Int.toString i)] } ^ "\n")
           );


          fprint (TextSVG.svgfooter ());
          TextIO.closeOut f;
          print "Done.\n"
      end
end

val () = Grid.go ()
