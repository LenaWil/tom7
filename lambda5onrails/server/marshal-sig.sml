signature MARSHAL =
sig

  exception Marshal of string

  (* unmarshal dict bytes *)
  val unmarshal : Bytecode.exp -> string -> Bytecode.exp

  (* marshal dict value *)
  val marshal : Bytecode.exp -> Bytecode.exp -> string

end