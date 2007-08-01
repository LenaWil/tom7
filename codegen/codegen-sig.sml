
signature CODEGEN =
sig

  exception Codegen of string
  
  (* This could be arranged in a slicker way, perhaps, by using an
     extensible type to allow other worldkinds to be implemented
     without changing this datatype and implementation. But given
     the amount of work required in adding a new worldkind, adding
     a new case here is trivial. *)

  (* code represents all the code necessary for a given world *)
  datatype code =
    CodeJS of { prog : Javascript.Program.t }
  | CodeB  of { prog : Bytecode.program }

  (* generates all the code for each world. *)
  val generate : CPS.program -> (string * code) list

end
