
structure PEToSVG =
struct

    exception PEToSVG of string

    (* FIXME: Actually this writes to stdout! duh! *)
    val svgout = Params.param "" 
        (SOME ("-o",
               "SVG output file; otherwise derive this " ^
               "from the input filename.")) "svgout"

    fun makebounds bounds ({ blocks = v, ... } : PEC.pecfile) =
        let
            fun oneblock ({ stitches, ... } : PEC.stitchblock) =
                Vector.app (fn (x, y) =>
                            Bounds.boundpoint bounds (real x, real y)) stitches
        in
            Vector.app oneblock v
        end

    fun main inputfile =
      let 
          val reader = Reader.fromfile inputfile
          val ext = StringUtil.lcase (#2 (FSUtil.splitext inputfile))
          val pec = 
              case ext of
                  "pec" => (PEC.readpec reader 
                            handle PEC.PEC s => raise PEToSVG s)
                | "pes" => (PES.readpes reader 
                            handle PES.PES s => raise PEToSVG s)
                | _ => raise PEToSVG "file must end with PEC or PES"

          val bounds = Bounds.nobounds ()
          val () = makebounds bounds pec
          val () = Bounds.addmarginfrac bounds 0.035 

          val width = Real.trunc (Bounds.width bounds)
          val height = Real.trunc (Bounds.height bounds)

          fun xtos x = TextSVG.rtos (Bounds.offsetx bounds (real x))
          fun ytos y = TextSVG.rtos (Bounds.offsety bounds (real y))
          fun prpt (x, y) = print (xtos x ^ "," ^ ytos y ^ " ")

          fun printpolyline ({ stitches = coords, ... } : PEC.stitchblock) =
              let in
                  print ("<polyline stroke-linejoin=\"round\" " ^ (* " *)
                         "fill=\"none\" stroke=\"#000000\" " ^
                         " stroke-width=\"0.7\" points=\""); (* " *)
                  Vector.app prpt coords;
                  print "\"/>\n" (* " *)
              end

          fun printpec ({ blocks, ... } : PEC.pecfile) =
              Vector.app printpolyline blocks

      in
          print (TextSVG.svgheader { x = 0, y = 0, 
                                     width = width, 
                                     height = height,
                                     generator = "pes-tosvg.sml" });
          printpec pec;
          
          print (TextSVG.svgfooter ())

      end

    val () = Params.main1 
        ("Takes a single argument, the PEC or PES file to convert.") main
        handle PEToSVG s =>
            (TextIO.output(TextIO.stdErr, "Failed: " ^ s))
end