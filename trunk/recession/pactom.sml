
structure PacTom :> ALGORITHM =
struct

    fun floatfromre re s =
	case RE.find re s of 
	    NONE => NONE
	  | SOME f => Real.fromString (f 1)
    
    fun findn re s n =
	case RE.find re s of
	    NONE => NONE
	  | SOME f => SOME (f n) handle _ => NONE

    fun sopt NONE = "??"
      | sopt (SOME s) = s

    (* For the Garmin Connect feed, the title is interesting (unless it's
       "Untitled"), and then the description is HTML (as CDATA)
       containing a table with some links and data. *)
    fun algorithm { guid : string,
                    link : string option,
                    title : string,
                    description : string,
                    date : Date.date,
                    body : XML.tree list } : { url : string,
                                               title : string } option =
	(* This filter already seems to happen in the garmin feed, but
	   protect against that behavior changing. *)
	if title = "Untitled"
	then NONE
	else
	case floatfromre "Distance: </td><td>([0-9]+(\\.[0-9]+)?) Mile" description of 
	    NONE => NONE (* ? *)
	  | SOME miles =>
		let
		    val elev = findn "Elevation Gain: </td><td>([0-9,]+) Feet" description 1
		    val time = findn "Time: </td><td>([0-9:]+)</td>" description 1
		    val link = getOpt (link, "#")
		in
		    print ("Title: " ^ title ^ "\n");
		    print ("Miles: " ^ Real.fmt (StringCvt.FIX (SOME 1)) miles ^ "\n");
		    print ("Elev: " ^ sopt elev ^ "\n");
		    print ("Time: " ^ sopt time ^ "\n");

		    SOME
		    { title =
		      "<a class=\"pttitle\" href=\"" ^ link ^ 
		      "\">" ^ title ^ "</a> &mdash; " ^
		      "<span class=\"ptnummiles\">" ^ Real.fmt (StringCvt.FIX (SOME 1)) miles ^
		      "</span><span class=\"ptmiles\">mi.</span> in " ^
		      "<span class=\"pttime\">" ^ sopt time ^ "</span> &nbsp;" ^
		      "<span class=\"ptelev\">(<span class=\"ptelevnum\">" ^ sopt elev ^ "</span>" ^
		      "ft. gain)</span>",
		      url = link }
		end

end