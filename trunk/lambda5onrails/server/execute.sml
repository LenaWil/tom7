
structure Execute =
struct

  exception Execute of string

  type instance =
    { prog : Bytecode.program
      
      }

  fun new p = { prog = p } (* raise Execute "unimplemented" *)

end
