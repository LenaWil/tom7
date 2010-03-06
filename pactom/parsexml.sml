structure ParseXML = 
struct 

  val () =
      case CommandLine.arguments () of
          [f] => print (XML.tostring
              (XML.parsefile f
               handle (e as (XML.XML s)) => (print ("Error: " ^ s); raise e)) ^ "\n")
        | _ => print "parsexml file.xml\n"

end