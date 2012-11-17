
val RADIX = 60 * 24

exception Illegal
val lines = Script.linesfromfile "pd3.txt"
fun parse3 line =
    case map Int.fromString (String.fields (StringUtil.ischar #",") line) of
        [SOME a, SOME b, SOME c] => SOME(a, b, c)
      | nil => NONE (* Allow blank lines *)
      | _ => raise Illegal

val possible = List.mapPartial parse3 lines

val rtos = Real.fmt (StringCvt.FIX (SOME 2))
val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

val f = TextIO.openOut "grid.svg"
fun fprint s = TextIO.output (f, s)

val () =
let
    fun makegrid2x2 l size =
        let
            val CELL_WIDTH = size / (real RADIX)
            fun onecell (x, y) =
                fprint ("<rect x=\"" ^ rtos (real x * CELL_WIDTH) ^
                        "\" y=\"" ^ rtos (real y * CELL_WIDTH) ^
                        "\" width=\"" ^ rtos CELL_WIDTH ^
                        "\" height=\"" ^ rtos CELL_WIDTH ^
                        "\" fill=\"#000\" />\n")
(*                        "\" style=\"fill:#000000;opacity:0.5\" />\n") *)
        in
             app onecell l
        end

    val GRAPHIC_SIZE = 1024

    fun cmp2 ((a, b), (aa, bb)) =
        case Int.compare (a, aa) of
           EQUAL => Int.compare (b, bb)
         | order => order

    val fposs = map (fn (a, b, c) => (a, b)) possible
    val fposs = ListUtil.sort_unique cmp2 fposs
in
    fprint (TextSVG.svgheader { x = 0, y = 0,
                                width = GRAPHIC_SIZE,
                                height = GRAPHIC_SIZE,
                                generator = "grid.sml" });

    makegrid2x2 fposs (real GRAPHIC_SIZE);

         (* XXX show headings
          Util.for 0 (M.radix - 1)
          (fn i =>
           fprint (TextSVG.svgtext { x = ~0.5 * CELL_WIDTH,
                                     y = real i * CELL_WIDTH + (0.8 * CELL_WIDTH),
                                     face = "Franklin Gothic Medium",
                                     size = 0.6 * CELL_WIDTH,
                                     text = [("#000000", tostring (M.fromint i))] })
           );
          *)

    fprint (TextSVG.svgfooter ());
    TextIO.closeOut f
end
