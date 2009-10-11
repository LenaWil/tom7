structure ParseXML = 
struct 

  val () =
      case CommandLine.arguments () of
	  [f] => ignore
	      (XML.parsefile f
	       handle (e as (XML.XML s)) => (print ("Error: " ^ s); raise e))
	| _ => print "parsexml file.xml\n"

end