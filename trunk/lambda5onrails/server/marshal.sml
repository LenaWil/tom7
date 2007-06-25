structure Marshal =
struct

  structure B = Bytecode

  exception Marshal of string

  fun unmarshal bytes : B.exp = raise Marshal "unmarshal unimplemented"

  fun marshal (dict : B.exp) (value : B.exp) : string = raise Marshal "marshal unimplemented"

end
