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
      (* values like alllam are represented as total functions *)
    | Return of exp
      (* but expressions are CPS-converted. *)
    | End 

  (* XXX should really make exp/val distinction here *)
  and exp =
      Record of (label * exp) list
    | Project of label * exp
    | Primcall of string * exp list
    (* from allapp. call a total function that returns a value *)
    | Call of exp * exp list
    | Var of string
    | Int of IntConst.intconst
    | String of string
    | Inj of string * exp option
    | Primop of Primop.primop * exp list

    | Marshal of exp * exp

    | Ref of exp ref

    | Dat of { d : exp, a : exp }
    | Dp of primdict
    | Drec of (string * exp) list
    | Dsum of (string * exp option) list
    | Dexists of { d : string, a : exp list }
    | Dall of string list * exp
    | Dsham of { d : string, v : exp }
    (* | Dref of string *)

    (* "variable" *)
    | Dlookup of string

      (* XXX Dmu, *)

  datatype global = 
      FunDec of (string list * statement) vector
    | OneDec of string list * statement
    | Absent

  type program =
    { globals : global vector,
      (* assumed a .0 function of no arguments *)
      main : int option }

end
