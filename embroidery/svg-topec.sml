
structure SVGToPEC =
struct

    exception SVGToPEC of string
    datatype tree = datatype XML.tree

    val pecout = Params.param "" 
        (SOME ("-o",
               "PEC output file; otherwise derive this " ^
               "from the input filename.")) "pecout"

    fun main inputfile =
      let 
          val xml : XML.tree = XML.parsefile inputfile

	  val blocks = ref (nil : PEC.stitchblock list)

	  fun processtags (Elem (("polyline", attrs), nil)) =
	      (case XML.getattr attrs "points" of
		   NONE => TextIO.output(TextIO.stdErr,
					 "polyline without points?\n")
		 | SOME s =>
		    (case SVG.parsepointsstring s of
			 NONE => TextIO.output(TextIO.stdErr,
					       "ignoring polyline with " ^
					       "unparsable points")
		       | SOME cl => 
			  let
			      (* as integer millimeters *)
			      val cl = map (fn (x, y) =>
					    (Real.round x, Real.round y)) cl
			  in
			      blocks := { colorindex = 0,
					  stitches = Vector.fromList cl } ::
			      !blocks
			  end))
	    | processtags (Elem ((tag, _), _)) =
		   TextIO.output(TextIO.stdErr,
				 "ignoring toplevel <" ^ tag ^ ">\n")
	    | processtags (Text _) = ()

	  val () =
	      (case xml of
		   Elem (("svg", _), body) => app processtags body
		 | _ => raise SVGToPEC "expected <svg>")

	  val pecfile = { blocks = Vector.fromList (rev (!blocks)) }

	  val outfile =
	      case (!pecout, FSUtil.splitext inputfile) of
		  ("", (base, _)) => base ^ ".pec"
		| (file, _) => file
      in
	  print ("Parsed " ^ Int.toString (Vector.length (#blocks pecfile)) ^
		 " stitch blocks.\n");
	  
	  PEC.writefile outfile pecfile;

	  print ("Wrote PEC file to " ^ outfile ^ ".\n");

	  ()
      end

    val () = Params.main1 
        ("Takes a single argument, the SVG file to convert.") main
        handle SVGToPEC s =>
            (TextIO.output(TextIO.stdErr, "Failed: " ^ s))
	     | PEC.PEC s =>
	    (TextIO.output(TextIO.stdErr, "PEC error: " ^ s))
end