
signature EXECUTE =
sig

  exception Execute of string

  type instance

  (* Create a new instance from a parsed program *)
  val new : Bytecode.program -> instance


end
