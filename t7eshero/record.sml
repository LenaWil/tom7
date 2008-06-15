(* Per-song records and medals *)
structure Record :> RECORD =
struct
    exception Record of string

    datatype recordtype =
        Misses of int
        (* only strummed up for the whole song *)
      | UpStrum
        (* never hammered a note (hard to measure?) *)
      | AuthenticStrummer
        (* never strummed a hammer note *)
      | AuthenticHammer
      | Percent of int
      (* | Dance (lots of shaking accelerometers) *)

    (* ty, seconds since epoch *)
    type record = recordtype * IntInf.int

    (* XXX serialize *)
    fun tostring (r, i) =
	(IntInf.toString i ^ "|" ^
	 (case r of
	     Misses x => "M|" ^ Int.toString x
	   | UpStrum => "U"
	   | AuthenticStrummer => "A"
	   | AuthenticHammer => "H"
	   | Percent x => "P|" ^ Int.toString x))

    fun fromstring s =
	let val l = String.tokens (StringUtil.ischar #"|") s
	    val when = valOf (IntInf.fromString (hd l))
	    val what =
		case tl l of
		    ["M", x] => Misses (valOf (Int.fromString x))
		  | ["P", x] => Percent (valOf (Int.fromString x))
		  | ["U"] => UpStrum
		  | ["A"] => AuthenticStrummer
		  | ["H"] => AuthenticHammer
		  | _ => raise Record "bad/unknown record?"
	in
	    (what, when)
	end handle Empty => raise Record "bad record" (* hd *)
		 | Option => raise Record "bad record" (* valOf *)
end