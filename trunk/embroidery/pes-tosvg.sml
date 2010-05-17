
structure PESToSVG =
struct

    val svgout = Params.param "" 
        (SOME ("-o",
               "SVG output file; otherwise derive this " ^
               "from the input filename.")) "svgout"

    fun makebounds bounds ({ blocks = v, ... } : PES.pesfile) =
	let
	    fun oneblock ({ stitches, ... } : PES.stitchblock) =
		Vector.app (fn (x, y) =>
			    Bounds.boundpoint bounds (real x, real y)) stitches
	in
	    Vector.app oneblock v
	end

    fun main inputfile =
        let
          val r = Reader.fromfile inputfile
	  val bounds = Bounds.nobounds ()
          val (p : PES.pesfile) = PES.readpes r
	  val () = makebounds bounds p
          val () = Bounds.addmarginfrac bounds 0.035 

          val width = Real.trunc (Bounds.width bounds)
          val height = Real.trunc (Bounds.height bounds)

          fun xtos x = TextSVG.rtos (Bounds.offsetx bounds (real x))
          fun ytos y = TextSVG.rtos (Bounds.offsety bounds (real y))
          fun prpt (x, y) = print (xtos x ^ "," ^ ytos y ^ " ")

          fun printpolyline ({ stitches = coords, ... } : PES.stitchblock) =
              let in
                  print ("<polyline stroke-linejoin=\"round\" " ^ (* " *)
                         "fill=\"none\" stroke=\"#000000\" " ^
                         " stroke-width=\"0.7\" points=\""); (* " *)
                  Vector.app prpt coords;
                  print "\"/>\n" (* " *)
              end

	  fun printpes ({ blocks, ... } : PES.pesfile) =
	      Vector.app printpolyline blocks

        in
	  print (TextSVG.svgheader { x = 0, y = 0, 
				     width = width, 
				     height = height,
				     generator = "pes-tosvg.sml" });
          printpes p;
	  
	  print (TextSVG.svgfooter ())
        end

    val () = Params.main1 
        ("Takes a single argument, the PES file to convert.") main

end