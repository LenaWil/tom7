
structure Cube =
struct
  val RADIX = 60

  exception Illegal
  val lines = Script.linesfromfile "possible-3.txt"
  fun parse3 line =
      case map Int.fromString (String.fields (StringUtil.ischar #",") line) of
          [SOME a, SOME b, SOME c] => SOME(a, b, c)
        | nil => NONE (* Allow blank lines *)
        | _ => raise Illegal

  val possible = List.mapPartial parse3 lines

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

  fun go () =
      let
          val f = TextIO.openOut "cube3.svg"
          fun fprint s = TextIO.output (f, s)

          val GRAPHIC_SIZE = 1024
          val LABEL_WIDTH = 64
          val LABEL_HEIGHT = 64
          val LABEL_GAP = 7

          val CELL_WIDTH = real GRAPHIC_SIZE / real (RADIX + 1)

          (* XXX need to do some kinda real rotation
          fun rot3 (xa, ya, za) (x, y, z) =
              let
              in
              end
              *)

          fun makecube l =
              let
                  fun onecell (x, y, z) =
                    let
                        (* fake rotation, looks terrible *)
                      val xx = real x * CELL_WIDTH + (real z / 60.0) * CELL_WIDTH
                      val yy = real y * CELL_WIDTH + (real z / 60.0) * CELL_WIDTH
                      (* val zz = real z * CELL_WIDTH *)

                      val rad = 3.0 + (real z / 60.0) * 2.0
                    in
                      fprint
                        ("<circle cx=\"" ^ rtos xx ^ "\" " ^
                         "cy=\"" ^ rtos yy ^ "\" " ^
                         "r=\"" ^ rtos rad ^ "\" fill=\"#000\" opacity=\"0.2\" />\n")
                    end
              in
                  app onecell l
              end

      in
          print ("There are " ^ Int.toString (length possible) ^ " possibilities\n");
          fprint (TextSVG.svgheader { x = 0, y = 0,
                                      width = GRAPHIC_SIZE + LABEL_WIDTH,
                                      height = GRAPHIC_SIZE + LABEL_HEIGHT,
                                      generator = "grid.sml" });

          (*
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
          *)

          (* Fill in the grid *)
          makecube possible;

          (*
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
          *)

          fprint (TextSVG.svgfooter ());
          TextIO.closeOut f;
          print "Done.\n"
      end
end

val () = Cube.go ()
