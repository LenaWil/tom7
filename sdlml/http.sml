structure HTTP :> HTTP =
struct

  datatype result =
      Success of string
    | NetworkFailure of string
    | Rejected of string

  exception HTTP of string

  fun parse_url url =
      if String.substring (url, 0, 7) = "http://"
      then
	  let val url = String.substring(url, 7, size url - 7)
	      val (site, path) = StringUtil.token (StringUtil.ischar #"/") url
	      val path = "/" ^ path
	      val (site, port) =
		  case String.fields (StringUtil.ischar #":") site of
		      [site] => (site, 80)
		    | [site, port] =>
			  (site, 
			   case Int.fromString port of
			       NONE => raise HTTP "Alleged URL has non-numeric port"
			     | SOME port => 
				   if port <= 0 orelse port > 65535
				   then raise HTTP "Alleged URL has port out of range"
				   else port)
	  in
	      raise HTTP "unimplemented"
	  end
      else raise HTTP "Alleged URL doesn't start with http://"
	  
  fun get_url url cb = raise HTTP "unimplemented"
      

end