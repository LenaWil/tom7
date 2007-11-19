signature BYTECODEGEN =
sig

  exception ByteCodegen of string

  (* generate labels hostname global

     from a single named global (or NONE if this global isn't
     implemented on this host), generate a Bytecode global that
     implements it *)
  val generate : { labels : string vector,
                   labelmap : int StringMap.map } ->
                   string ->
                   (string * CPS.cglo option) -> 
                   Bytecode.global

end