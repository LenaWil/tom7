signature MARSHAL =
sig

  exception Marshal of string

  (* At constant type? *)
  val unmarshal : string -> Bytecode.exp

  (* marshal dict value *)
  val marshal : Bytecode.exp -> Bytecode.exp -> string

end