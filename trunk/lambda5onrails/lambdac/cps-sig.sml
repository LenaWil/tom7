
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

  datatype primcon = 
    VEC 
  | REF
    (* the type of dictionaries for this type *)
  | DICT
  | INT
  | STRING

  datatype 'ctyp ctypfront =
      At of 'ctyp * world
    | Cont of 'ctyp list
    | Conts of 'ctyp list list
    | AllArrow of { worlds : var list, tys : var list, vals : 'ctyp list, body : 'ctyp }
    | WExists of var * 'ctyp
    | TExists of var * 'ctyp list
    | Product of (string * 'ctyp) list
    | Addr of world
    | Mu of int * (var * 'ctyp) list
    | Sum of (string * 'ctyp IL.arminfo) list
    | Primcon of primcon * 'ctyp list
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
    (* type var, contents vars *)
    | TUnpack of var * (var * ctyp) list * 'cval * 'cexp
    | Case of 'cval * var * (string * 'cexp) list * 'cexp
    | ExternVal of var * string * ctyp * world option * 'cexp
    | ExternWorld of var * string * 'cexp
    (* always kind 0; optional argument is a value import of the dictionary
       for that type *)
    | ExternType of var * string * (var * string) option * 'cexp

  and ('cexp, 'cval) cvalfront =
           (*   fn    arg   argt         body *)
      Lams of (var * (var * ctyp) list * 'cexp) list
    | Fsel of 'cval * int
    | Int of IL.intconst
    | String of string
    | Record of (string * 'cval) list
    | Hold of world * 'cval
    | WPack of world * 'cval
    | TPack of ctyp * 'cval list
    | Sham of 'cval
    | Inj of string * ctyp * 'cval option
    | Roll of ctyp * 'cval
    | Unroll of 'cval
    | Var of var
    | UVar of var
    (* later expanded to the actual dictionary, using invariants established in
       CPSDict and Closure conversion *)
    | Dictfor of ctyp
    (* supersedes WLam, TLam and VLam. quantifies worlds, types, and vars (in that
       order) over the body, which must be a value itself. applications of vlams
       are considered valuable. *)
    | AllLam of { worlds : var list, tys : var list, vals : var list, body : 'cval }
    | AllApp of { f : 'cval, worlds : world list, tys : ctyp list, vals : 'cval list }


  (* subXY = substitute X/v in Y producing Y; not all combinations make sense *)
  val subww : world -> var -> world -> world
  val subwt : world -> var -> ctyp -> ctyp
  val subwv : world -> var -> cval -> cval
  val subwe : world -> var -> cexp -> cexp

  val subtt : ctyp -> var -> ctyp -> ctyp
  val subtv : ctyp -> var -> cval -> cval
  val subte : ctyp -> var -> cexp -> cexp

  val subvv : cval -> var -> cval -> cval
  val subve : cval -> var -> cexp -> cexp


  val ctyp_cmp : ctyp * ctyp -> order
  val ctyp_eq  : ctyp * ctyp -> bool

  val ctyp : ctyp -> ctyp ctypfront
  val cexp : cexp -> (cexp, cval) cexpfront
  val cval : cval -> (cexp, cval) cvalfront

  (* utilities *)

  (* apply the function to each immediate subterm (of type ctyp) and
     return the reconstructed type *)
  val pointwiset : (ctyp -> ctyp) -> ctyp -> ctyp
  (* Same, but to subterms that are types, values, expressions *)
  val pointwisee : (ctyp -> ctyp) -> (cval -> cval) -> (cexp -> cexp) -> cexp -> cexp
  val pointwisev : (ctyp -> ctyp) -> (cval -> cval) -> (cexp -> cexp) -> cval -> cval

  (* injective constructors *)
  val At' : ctyp * world -> ctyp
  val Cont' : ctyp list -> ctyp
  val WExists' : var * ctyp -> ctyp
  val TExists' : var * ctyp list -> ctyp
  val Product' : (string * ctyp) list -> ctyp
  val Addr' : world -> ctyp
  val Mu' : int * (var * ctyp) list -> ctyp
  val Sum' : (string * ctyp IL.arminfo) list -> ctyp
  val Primcon' : primcon * ctyp list -> ctyp
  val Conts' : ctyp list list -> ctyp
  val Shamrock' : ctyp -> ctyp
  val TVar' : var -> ctyp
  val AllArrow' : { worlds : var list, tys : var list, vals : ctyp list, body : ctyp } -> ctyp

  val Call' : cval * cval list -> cexp
  val Halt' : cexp
  val Go' : world * cval * cexp -> cexp
  val Proj' : var * string * cval * cexp -> cexp
  val Primop' : var list * primop * cval list * cexp -> cexp
  val Put' : var * ctyp * cval * cexp -> cexp
  val Letsham' : var * cval * cexp -> cexp
  val Leta' : var * cval * cexp -> cexp
  val WUnpack' : var * var * cval * cexp -> cexp
  val TUnpack' : var * (var * ctyp) list * cval * cexp -> cexp
  val Case' : cval * var * (string * cexp) list * cexp -> cexp
  val ExternVal' : var * string * ctyp * world option * cexp -> cexp
  val ExternWorld' : var * string * cexp -> cexp
  val ExternType' : var * string * (var * string) option * cexp -> cexp

  val Lams' : (var * (var * ctyp) list * cexp) list -> cval
  val Fsel' : cval * int -> cval
  val Int' : IL.intconst -> cval
  val String' : string -> cval
  val Record' : (string * cval) list -> cval
  val Hold' : world * cval -> cval
  val WPack' : world * cval -> cval
  val TPack' : ctyp * cval list -> cval
  val Sham' : cval -> cval
  val Inj' : string * ctyp * cval option -> cval
  val Roll' : ctyp * cval -> cval
  val Unroll' : cval -> cval
  val Dictfor' : ctyp -> cval
  val AllLam' : { worlds : var list, tys : var list, vals : var list, body : cval } -> cval
  val AllApp' : { f : cval, worlds : world list, tys : ctyp list, vals : cval list } -> cval
  val Var' : var -> cval
  val UVar' : var -> cval

  (* derived forms *)
  val WAll' : var * ctyp -> ctyp
  val TAll' : var * ctyp -> ctyp
  val Lam' : (var * (var * ctyp) list * cexp) -> cval
  val WApp' : cval * world -> cval
  val TApp' : cval * ctyp -> cval
  val WLam' : var * cval -> cval
  val TLam' : var * cval -> cval
  val Zerocon' : primcon -> ctyp

end
