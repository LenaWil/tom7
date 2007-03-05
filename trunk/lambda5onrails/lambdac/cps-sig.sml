
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

  datatype 'ctyp ctypfront =
      At of 'ctyp * world
    | Cont of 'ctyp list
    | AllArrow of { worlds : var list, tys : var list, vals : typ list, body : 'ctyp }
    | WExists of var * 'ctyp
    | Product of (string * 'ctyp) list
    | Addr of world
    | Mu of int * (var * 'ctyp) list
    | Sum of (string * 'ctyp IL.arminfo) list
    | Primcon of primcon * 'ctyp list
    | Conts of 'ctyp list list
    | Shamrock of 'ctyp
    | TVar of var

  datatype primop = 
    (* binds uvar *)
    LOCALHOST 
    (* binds regular var *)
  | BIND 
  | PRIMCALL of { sym : string, dom : ctyp list, cod : ctyp }

  datatype ('cexp, 'cval) cexpfront =
      Call of 'cval * 'cval list
    | Halt
    | Go of world * 'cval * 'cexp
    | Proj of var * string * 'cval * 'cexp
    | Primop of var list * primop * 'cval list * 'cexp
    | Put of var * ctyp * 'cval * 'cexp
    | Letsham of var * 'cval * 'cexp
    | Leta of var * 'cval * 'cexp
    (* world var, contents var *)
    | WUnpack of var * var * 'cval * 'cexp
    | Case of 'cval * var * (string * 'cexp) list * 'cexp
    | ExternVal of var * string * ctyp * world option * 'cexp
    | ExternWorld of var * string * 'cexp
    (* always kind 0 *)
    | ExternType of var * string * 'cexp

  and ('cexp, 'cval) cvalfront =
      Lams of (var * var list * 'cexp) list
    | Fsel of 'cval * int
    | Int of IL.intconst
    | String of string
    | Record of (string * 'cval) list
    | Hold of world * 'cval
    | WPack of world * 'cval
    | Sham of 'cval
    | Inj of string * ctyp * 'cval option
    | Roll of ctyp * 'cval
    | Unroll of 'cval
    | Var of var
    | UVar of var
    (* supersedes WLam, TLam and VLam. quantifies worlds, types, and vars (in that
       order) over the body, which must be a value itself. applications of vlams
       are considered valuable. *)
    | AllLam of { worlds : var list, tys : var list, vals : var list, body : 'cval }
    | AllApp of { f : 'cval, worlds : world list, tys : ctyp list, vals : 'cval list }

  val ctyp : ctyp -> ctyp ctypfront
  val cexp : cexp -> (cexp, cval) cexpfront
  val cval : cval -> (cexp, cval) cvalfront

  (* injective constructors *)
  val At' : ctyp * world -> ctyp
  val Cont' : ctyp list -> ctyp
  val WExists' : var * ctyp -> ctyp
  val Product' : (string * ctyp) list -> ctyp
  val Addr' : world -> ctyp
  val Mu' : int * (var * ctyp) list -> ctyp
  val Sum' : (string * ctyp IL.arminfo) list -> ctyp
  val Primcon' : primcon * ctyp list -> ctyp
  val Conts' : ctyp list list -> ctyp
  val Shamrock' : ctyp -> ctyp
  val TVar' : var -> ctyp
  val AllArrow' : { worlds : var list, tys : var list, vals : typ list, body : ctyp } -> ctyp

  val Call' : cval * cval list -> cexp
  val Halt' : cexp
  val Go' : world * cval * cexp -> cexp
  val Proj' : var * string * cval * cexp -> cexp
  val Primop' : var list * primop * cval list * cexp -> cexp
  val Put' : var * ctyp * cval * cexp -> cexp
  val Letsham' : var * cval * cexp -> cexp
  val Leta' : var * cval * cexp -> cexp
  val WUnpack' : var * var * cval * cexp -> cexp
  val Case' : cval * var * (string * cexp) list * cexp -> cexp
  val ExternVal' : var * string * ctyp * world option * cexp -> cexp
  val ExternWorld' : var * string * cexp -> cexp
  val ExternType' : var * string * cexp -> cexp

  val Lams' : (var * var list * cexp) list -> cval
  val Fsel' : cval * int -> cval
  val Int' : IL.intconst -> cval
  val String' : string -> cval
  val Record' : (string * cval) list -> cval
  val Hold' : world * cval -> cval
  val WPack' : world * cval -> cval
  val Sham' : cval -> cval
  val Inj' : string * ctyp * cval option -> cval
  val Roll' : ctyp * cval -> cval
  val Unroll' : cval -> cval
  val AllLam' : { worlds : var list, tys : var list, vals : var list, body : cval } -> cval
  val AllApp' : { f : cval, worlds : world list, tys : ctyp list, vals : cval list } -> cval
  val Var' : var -> cval
  val UVar' : var -> cval

  (* derived forms *)
  val WAll' : var * ctyp -> ctyp
  val TAll' : var * ctyp -> ctyp
  val Lam' : (var * var list * cexp) -> cval
  val WApp' : cval * world -> cval
  val TApp' : cval * ctyp -> cval
  val WLam' : var * cval -> cval
  val TLam' : var * cval -> cval

end
