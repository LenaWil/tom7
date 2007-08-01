(* This is the low-level interpreted language that is run in the server.
   It is only called "bytecode" to indicate its purpose as a portable
   interpreted language, not because it has anything to do with bytes. *)

structure Bytecode =
struct

  type label = string

  datatype primdict =
    Dcont | Dconts | Daddr | Ddict | Dint | Dstring | Dvoid | Daa | Dref | Dw

  datatype statement =
      Bind of string * exp * statement
    | End 
      (* global id, offset within that, args *)
    | Jump of exp * exp * exp list
    | Case of { obj : exp, 
                (* for arms, not def *)
                var : string,
                arms : (string * statement) list,
                def : statement }
      (* addr, bytes *)
    | Go of exp * exp
    | Error of string

  and exp =
      Record of (label * exp) list
    | Project of label * exp
    | Primcall of string * exp list
    | Var of string
    | Int of IntConst.intconst
    | String of string
    | Inj of string * exp option

    | Marshal of exp * exp

    | Dat of { d : exp, a : exp }
    | Dp of primdict
    | Drec of (string * exp) list
    | Dsum of (string * exp option) list
    | Dexists of { d : string, a : exp list }
    | Dall of string list * exp
    (* | Dref of string *)

    (* "variable" *)
    | Dlookup of string

      (* XXX Dmu, *)

  datatype global = 
      FunDec of (string list * statement) vector
    | Absent

  type program =
    { globals : global vector,
      (* assumed a .0 function of no arguments *)
      main : int option }

end
