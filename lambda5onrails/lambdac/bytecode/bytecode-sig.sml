(* This is the low-level interpreted language that is run in the server.
   It is only called "bytecode" to indicate its purpose as a portable
   interpreted language, not because it has anything to do with bytes. *)

signature BYTECODE =
sig

  type label = string

  datatype statement =
      Bind of string * exp * statement
    | End 
    | Jump of exp * exp list
    | Case of { obj : exp, var : string,
                arms : (string * statement) list,
                def : statement }

  and exp =
      Record of (label * exp) list
    | Project of label * exp
    | Primcall of (string * exp list)
    | Var of string
    | Int of IntConst.intconst


  datatype fundec = 
      FunDec of (string list * statement) vector
    | Absent

  type program =
    { globals : fundec vector,
      (* assumed a .0 function of no arguments *)
      main : int }

end
