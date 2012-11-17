
val RADIX = 60 * 24

exception Illegal
val lines = Script.linesfromfile "pd2.txt"
fun parse2 line =
    case map Int.fromString (String.fields (StringUtil.ischar #",") line) of
        [SOME a, SOME b] => SOME(a, b)
      | nil => NONE (* Allow blank lines *)
      | _ => raise Illegal

val possible = List.mapPartial parse2 lines


val rtos = Real.fmt (StringCvt.FIX (SOME 2))
val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

val f = TextIO.openOut "powerday2player.svg"
fun fprint s = TextIO.output (f, s)

val () =
let
    fun makegrid2x2 l size =
        let
            val CELL_WIDTH = size / real RADIX
            fun onecell (x, y) =
                fprint ("<rect x=\"" ^ rtos (real x * CELL_WIDTH) ^
                        "\" y=\"" ^ rtos (real y * CELL_WIDTH) ^
                        "\" width=\"" ^ rtos CELL_WIDTH ^
                        "\" height=\"" ^ rtos CELL_WIDTH ^
                        "\" style=\"fill:#800;opacity:0.5\" />\n")
        in
             app onecell l
        end

    val GRAPHIC_SIZE = 1024
in
    print ("There are " ^ Int.toString (length possible) ^ " possibilities\n");
    fprint (TextSVG.svgheader { x = 0, y = 0,
                                width = GRAPHIC_SIZE,
                                height = GRAPHIC_SIZE,
                                generator = "grid.sml" });

    makegrid2x2 possible (real GRAPHIC_SIZE);

    fprint (TextSVG.svgfooter ());
    TextIO.closeOut f;
    print "Done.\n"
end
