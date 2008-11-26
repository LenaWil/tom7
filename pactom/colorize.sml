
val () = print "hi!"

structure Colorize = 
struct 

  val x = XML.parsefile "test.xml"
      handle (e as (XML.XML s)) => (print ("Error: " ^ s); raise e)

  datatype tree = datatype XML.tree

  fun printxml (Text s) = "\"" ^ s ^ "\""
    | printxml (Elem ((s, attrs), tl)) =
      ("<" ^ s ^ ">" ^
       StringUtil.delimit "," (map printxml tl) ^
       "</" ^ s ^ ">")

  val () = print (printxml x)
end