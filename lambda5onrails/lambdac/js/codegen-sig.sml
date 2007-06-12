signature JSCODEGEN =
sig

  exception JSCodegen of string

  (* from a single named global (or NONE if this global isn't
     implemented on this host), generate a javascript expression that
     implements it (presumably a function or array of functions) *)
  val generate : { labels : string vector,
                   labelmap : int StringMap.map } ->
                   (string * CPS.cglo option) -> 
                   Javascript.Exp.t 

end