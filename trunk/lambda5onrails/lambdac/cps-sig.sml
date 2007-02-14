
(* Wizard-like interface to CPS internal language *)
signature CPS =
sig

  type var = Variable.var

  exception CPS of string

  (* CPS expressions *)
  type cexp
  type cval
  type ctyp

  datatype arminfo = datatype IL.arminfo
  datatype world = W of var

  datatype primcon = VEC | REF
  datatype primop = LOCALHOST

  (* need cps declarations instead of expressions, I guess? *)
  datatype cpsunit = XXX

  datatype 'ctyp ctypfront =
      At of 'ctyp * world
    | Cont of 'ctyp list
    | WAll of var * 'ctyp
    | WExists of var * 'ctyp
    | Product of (string * 'ctyp) list
    | Addr of world
    | Mu of int * (var * 'ctyp) list
    | Sum of (string * 'ctyp IL.arminfo) list
    | Primcon of primcon * 'ctyp list
    | Conts of 'ctyp list list
    | Shamrock of 'ctyp
    | TVar of var

  datatype ('cexp, 'cval) cexpfront =
      Call of 'cval * 'cval list
    | Halt
    | Go of world * 'cval * 'cexp
    | Proj of var * string * 'cval * 'cexp
    | Primop of primop * 'cval list * var list * 'cexp
    | Put of var * 'cval * 'cexp
    | Letsham of var * 'cval * 'cexp
    | Leta of var * 'cval * 'cexp
    (* world var, contents var *)
    | WUnpack of var * var * 'cval * 'cexp
    | Case of 'cval * var * (string * 'cexp) list * 'cexp

  and ('cexp, 'cval) cvalfront =
      Lams of (var * var list * 'cexp) list
    | Fsel of 'cval * int
    | Int of int
    | String of string
    | Record of (string * 'cval) list
    | Hold of world * 'cval
    | WLam of var * 'cval
    | TLam of var * 'cval
    | WPack of world * 'cval
    | WApp of 'cval * world
    | TApp of 'cval * ctyp
    | Sham of 'cval
    | Inj of string * ctyp * 'cval
    | Roll of ctyp * 'cval
    | Unroll of 'cval
    | Var of var
    | UVar of var

  val ctyp : ctyp -> ctyp ctypfront
  val cexp : cexp -> (cexp, cval) cexpfront
  val cval : cval -> (cexp, cval) cvalfront

end
