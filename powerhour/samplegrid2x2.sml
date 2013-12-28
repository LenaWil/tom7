
structure Grid =
struct
  (* XXX absolutely no performance argument for making these
     constants as opposed to command-line parameters! *)
  val MINUTES = 60
  val NCUPS = 7
  val NPLAYERS = 2

  val cxpointfile = "checkpoint-" ^ Int.toString MINUTES ^ "m-" ^
      Int.toString NPLAYERS ^ "p-" ^
      Int.toString NCUPS ^ "s.tf"

  val SamplesTF.DB { entries = db } = SamplesTF.DB.fromfile cxpointfile

  structure IIM = SplayMapFn(type ord_key = IntInf.int
                             val compare = IntInf.compare)

  exception Illegal
  val allcounts = ref (IIM.empty)
  fun setct (_, _, s) =
      case IntInf.fromString s of
          NONE => raise Illegal
        | SOME i => allcounts := IIM.insert(!allcounts, i, ())
  val () = app setct db

  (* All unique counts, ascending *)
  val allcounts = map (fn (k, ()) => k) (IIM.listItemsi (!allcounts))
  val allcounts : IntInf.int vector = Vector.fromList allcounts

  val maxcount = Real.fromLargeInt (Vector.sub (allcounts,
                                                Vector.length allcounts - 1))

  (* Get the rank of i within 0..|maxcount|-1. It is expected
     that the number appears in the list! *)
  exception Bug
  (* PERF can use binary search obviously, but this whole program finishes
     in under a second *)
  fun getrank i =
      case VectorUtil.findi (fn x => x = i) allcounts of
          NONE => raise Bug
        | SOME (idx, _) => idx
  fun getfrac i =
      real (getrank i) / real (Vector.length allcounts - 1)

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  val rtos3 = Real.fmt (StringCvt.FIX (SOME 3))
  val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

  fun go () =
      let
          val f = TextIO.openOut ("sample" ^ Int.toString MINUTES ^ "min" ^
                                  Int.toString NPLAYERS ^ "players" ^
                                  Int.toString NCUPS ^ "states.svg")
          fun fprint s = TextIO.output (f, s)

          val GRAPHIC_SIZE = 1024
          val LABEL_WIDTH = 64
          val LABEL_HEIGHT = 64
          val LABEL_GAP = 7

          val CELL_WIDTH = real GRAPHIC_SIZE / real (MINUTES + 1)

          fun makegrid2x2 l =
              let
                  fun onecell (x :: y :: _, _, s) =
                      let
                          val ct = (valOf (IntInf.fromString s))
                          val f = getfrac ct

                          (* val f = Real.fromLargeInt ct / maxcount
                             val f = Math.sqrt (Math.sqrt f) *)

                          val ff = 1.0 - f
                          val ff = 0.175 + 0.825 * f
                      in
                          fprint ("<rect x=\"" ^ rtos (real x * CELL_WIDTH) ^
                                  "\" y=\"" ^ rtos (real y * CELL_WIDTH) ^
                                  "\" width=\"" ^ rtos CELL_WIDTH ^
                                  "\" height=\"" ^ rtos CELL_WIDTH ^
                                  "\" opacity=\"" ^ rtos3 ff ^
                                  "\" style=\"fill:#000\" />\n")
                      end
              in
                  app onecell l
              end

      in
          print ("There are " ^ Int.toString (length db) ^ " possibilities\n");
          fprint (TextSVG.svgheader { x = 0, y = 0,
                                      width = GRAPHIC_SIZE + LABEL_WIDTH,
                                      height = GRAPHIC_SIZE + LABEL_HEIGHT,
                                      generator = "grid.sml" });

          (* Vertical grid lines *)
          Util.for 0 MINUTES
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
          Util.for 0 MINUTES
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
          makegrid2x2 db;

          (* Vertical labels, at right. *)
          Util.for 0 MINUTES
          (fn i =>
           fprint (TextSVG.svgtext { x = CELL_WIDTH * real (MINUTES + 1) + real LABEL_GAP,
                                     y = real i * CELL_WIDTH + (0.7 * CELL_WIDTH),
                                     face = "Franklin Gothic Medium",
                                     size = 0.6 * CELL_WIDTH,
                                     text = [("#000", Int.toString i)] } ^ "\n")
           );

          (* Horizontal labels, on bottom *)
          Util.for 0 MINUTES
          (fn i =>
           fprint (TextSVG.svgtext { x = real i * CELL_WIDTH + (0.2 * CELL_WIDTH),
                                     y = CELL_WIDTH * real (MINUTES + 1) + real LABEL_GAP * 1.5,
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
