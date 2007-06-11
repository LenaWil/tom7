signature JSCODEGEN =
sig

  exception JSCodegen of string

  (* from a single named global (or NONE if this global isn't
     implemented on this host), generate a javascript statement that
     implements it (presumably a function declaration) *)
  val generate : { labels : string vector,
                   labelmap : int StringMap.map } ->
                   (string * CPS.cglo option) -> 
                   Javascript.Statement.t 

end