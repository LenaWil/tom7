
(* Wizard-like interface to CPS internal language *)
signature CPS =
sig

  type var = Variable.var

  exception CPS of string

  datatype arminfo = datatype IL.arminfo
  datatype world = W of var | WC of string

  datatype worldkind = datatype IL.worldkind

  datatype primcon = 
    VEC 
  | REF
    (* the type of dictionaries for this type *)
  | DICTIONARY
  | INT
  | STRING
  | EXN
    (* marshalled data *)
  | BYTES 

  (* Polymorphic since we use this to represent both types as classifiers (static)
     and types as data (dynamic). 'ctyp and 'world are the recursive instances of
     types and worlds, and 'tbind and 'wbind are the bindings--for data, these will
     be "fat" bindings that bind both a static component and a dynamic one. *)
  datatype ('tbind, 'ctyp, 'wbind, 'world) ctypfront =
      At of 'ctyp * 'world
    | Cont of 'ctyp list
    | Conts of 'ctyp list list
    | AllArrow of { worlds : 'wbind list, tys : 'tbind list, vals : 'ctyp list, body : 'ctyp }
    | WExists of 'wbind * 'ctyp
    | TExists of 'tbind * 'ctyp list
    | Product of (string * 'ctyp) list
    (* the type of a representation of this world *)
    | TWdict of 'world
    | Addr of 'world
    (* all variables bound in all arms *)
    | Mu of int * ('tbind * 'ctyp) list
    | Sum of (string * 'ctyp IL.arminfo) list
    | Primcon of primcon * 'ctyp list
    | Shamrock of 'ctyp
    | TVar of var

  type ctyp

  datatype primop = 
      (* binds uvar *)
      LOCALHOST 
      (* binds regular var *)
    | BIND 
      (* call to an extern label *)
    | PRIMCALL of { sym : string, dom : ctyp list, cod : ctyp }
      (* some built-in thing *)
    | NATIVE of { po : Primop.primop, tys : ctyp list }
      (* takes 'a dict and 'a -> bytes *)
    | MARSHAL
      (* takes a unit cont (or closure) and reifies it as a js string *)
    | SAY | SAY_CC

  datatype ('cexp, 'cval) cexpfront =
      Call of 'cval * 'cval list
    | Halt
    | Go of world * 'cval * 'cexp
      (* post closure conversion *)
    | Go_cc of { w : world, addr : 'cval, env : 'cval, f : 'cval }
      (* post marshaling conversion *)
    | Go_mar of { w : world, addr : 'cval, bytes : 'cval }
    | Primop of var list * primop * 'cval list * 'cexp
    | Put of var * 'cval * 'cexp
    | Letsham of var * 'cval * 'cexp
    | Leta of var * 'cval * 'cexp
    (* world var, XXXWD dict, contents var *)
    | WUnpack of var * var * 'cval * 'cexp
    (* typ var, dict var, contents vars *)
    | TUnpack of var * var * (var * ctyp) list * 'cval * 'cexp
    (* contents var only bound in arms, not default *)
    | Case of 'cval * var * (string * 'cexp) list * 'cexp
    | ExternVal of var * string * ctyp * world option * 'cexp
    | ExternWorld of string * worldkind * 'cexp
    (* always kind 0; optional argument is a value import of the 
       (valid) dictionary for that type *)
    | ExternType of var * string * (var * string) option * 'cexp

  and ('cexp, 'cval) cvalfront =
           (*   fn    arg   argt         body *)
      Lams of (var * (var * ctyp) list * 'cexp) list
    | Fsel of 'cval * int
    | Int of IL.intconst
    | String of string
    | Proj of string * 'cval
    | Record of (string * 'cval) list
    | Hold of world * 'cval
    (* XXXWD dict *)
    | WPack of world * 'cval
    (* tpack t as t' dict, [vals] *)
    | TPack of ctyp * ctyp * 'cval * 'cval list
    | Sham of var * 'cval
    | Inj of string * ctyp * 'cval option
    | Roll of ctyp * 'cval
    | Unroll of 'cval
    (* only after hoisting *)
    | Codelab of string
    | Var of var
    | UVar of var
    | WDictfor of world
    (* the only dictionary value is a constant (or a Var standing for one of these) *)
    | WDict of string
    (* later expanded to the actual dictionary, using invariants established in
       CPSDict and Closure conversion *)
    | Dictfor of ctyp
    | Dict of (var * var, 'cval, var * var, 'cval) ctypfront
    (* supersedes WLam, TLam and VLam. quantifies worlds, types, and vars (in that
       order) over the body, which must be a value itself. applications of vlams
       are considered valuable. *)
    | AllLam of { worlds : var list, tys : var list, vals : (var * ctyp) list, body : 'cval }
    | AllApp of { f : 'cval, worlds : world list, tys : ctyp list, vals : 'cval list }

    | VLeta of var * 'cval * 'cval
    | VLetsham of var * 'cval * 'cval
    (* type var, dict var, contents vars *)
    | VTUnpack of var * var * (var * ctyp) list * 'cval * 'cval

  datatype ('cexp, 'cval) cglofront =
      PolyCode of var * 'cval * ctyp (* @ var *)
      (* at a specific world constant *)
    | Code of 'cval * ctyp * string

  (* CPS expressions *)
  type cexp
  type cval
  type cglo

  type program = { 
                   (* The world constants. *)
                   worlds : (string * worldkind) list,
                   (* The globals (hoisted code). Before hoisting,
                      there is usually only the main *)
                   globals : (string * cglo) list,
                   (* The entry point for the program. *)
                   main : string }

  (* projections and injections *)
  val ctyp : ctyp -> (var, ctyp, var, world) ctypfront
  val cexp : cexp -> (cexp, cval) cexpfront
  val cval : cval -> (cexp, cval) cvalfront
  val cglo : cglo -> (cexp, cval) cglofront

  val ctyp' : (var, ctyp, var, world) ctypfront -> ctyp
  val cexp' : (cexp, cval) cexpfront -> cexp
  val cval' : (cexp, cval) cvalfront -> cval
  val cglo' : (cexp, cval) cglofront -> cglo


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


  val world_cmp : world * world -> order
  val world_eq : world * world -> bool
  val ctyp_cmp : ctyp * ctyp -> order
  val ctyp_eq  : ctyp * ctyp -> bool

  (* utilities *)

  val ptoct : Primop.potype -> ctyp

  (* is the variable free in this type (value; expression)? *)
  val freet : var -> ctyp -> bool
  val freev : var -> cval -> bool
  val freee : var -> cexp -> bool

  (* apply the function to each immediate subterm (of type ctyp) and
     return the reconstructed type *)
  val pointwiset : (ctyp -> ctyp) -> ctyp -> ctyp
  (* Same, but to subterms that are types, values, expressions *)
  val pointwisee : (ctyp -> ctyp) -> (cval -> cval) -> (cexp -> cexp) -> cexp -> cexp
  val pointwisev : (ctyp -> ctyp) -> (cval -> cval) -> (cexp -> cexp) -> cval -> cval

  (* with a mapper for worlds as well *)
  val pointwisetw : (world -> world) -> (ctyp -> ctyp) -> ctyp -> ctyp
  val pointwiseew : (world -> world) -> (ctyp -> ctyp) -> (cval -> cval) -> (cexp -> cexp) -> cexp -> cexp
  val pointwisevw : (world -> world) -> (ctyp -> ctyp) -> (cval -> cval) -> (cexp -> cexp) -> cval -> cval

  (* get the free value vars and value uvars in a value (expression) *)
  val freevarsv : cval -> Variable.Set.set * Variable.Set.set
  val freevarse : cexp -> Variable.Set.set * Variable.Set.set

  (* get the free type vars and world vars in a type (value; expression) *)
  val freesvarst : ctyp -> { t : Variable.Set.set, w : Variable.Set.set }
  val freesvarsv : cval -> { t : Variable.Set.set, w : Variable.Set.set }
  val freesvarse : cexp -> { t : Variable.Set.set, w : Variable.Set.set }

  (* injective constructors *)
  val At' : ctyp * world -> ctyp
  val Cont' : ctyp list -> ctyp
  val WExists' : var * ctyp -> ctyp
  val TExists' : var * ctyp list -> ctyp
  val Product' : (string * ctyp) list -> ctyp
  val Addr' : world -> ctyp
  val TWdict' : world -> ctyp
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
  val Go_cc' : { w : world, addr : cval, env : cval, f : cval } -> cexp
  val Go_mar' : { w : world, addr : cval, bytes : cval } -> cexp
  val Primop' : var list * primop * cval list * cexp -> cexp
  val Put' : var * cval * cexp -> cexp
  val Letsham' : var * cval * cexp -> cexp
  val Leta' : var * cval * cexp -> cexp
  val WUnpack' : var * var * cval * cexp -> cexp
  val Case' : cval * var * (string * cexp) list * cexp -> cexp
  val ExternVal' : var * string * ctyp * world option * cexp -> cexp
  val ExternWorld' : string * worldkind * cexp -> cexp
  val ExternType' : var * string * (var * string) option * cexp -> cexp
  val TUnpack' : var * var * (var * ctyp) list * cval * cexp -> cexp

  val Lams' : (var * (var * ctyp) list * cexp) list -> cval
  val Fsel' : cval * int -> cval
  val Int' : IL.intconst -> cval
  val String' : string -> cval
  val Record' : (string * cval) list -> cval
  val Hold' : world * cval -> cval
  val WPack' : world * cval -> cval
  val TPack' : ctyp * ctyp * cval * cval list -> cval
  val Sham' : var * cval -> cval
  val Inj' : string * ctyp * cval option -> cval
  val Roll' : ctyp * cval -> cval
  val Unroll' : cval -> cval
  val Dictfor' : ctyp -> cval
  val WDictfor' : world -> cval
  val AllLam' : { worlds : var list, tys : var list, vals : (var * ctyp) list, body : cval } -> cval
  val AllApp' : { f : cval, worlds : world list, tys : ctyp list, vals : cval list } -> cval
  val Codelab' : string -> cval
  val Var' : var -> cval
  val UVar' : var -> cval
  val VLeta' : var * cval * cval -> cval
  val VLetsham' : var * cval * cval -> cval
  val Proj' : string * cval -> cval
  val VTUnpack' : var * var * (var * ctyp) list * cval * cval -> cval
  val Dict' : (var * var, cval, var * var, cval) ctypfront -> cval
  val WDict' : string -> cval

  val PolyCode' : var * cval * ctyp -> cglo
  val Code' : cval * ctyp * string -> cglo

  (* derived forms *)
  val Dictionary' : ctyp -> ctyp
  val Lift' : var * cval * cexp -> cexp
  val Bind' : var * cval * cexp -> cexp
  val Bindat' : var * world * cval * cexp -> cexp
  val Marshal' : var * cval * cval * cexp -> cexp
  val Say' : var * cval * cexp -> cexp
  val Say_cc' : var * cval * cexp -> cexp
  val WAll' : var * ctyp -> ctyp
  val TAll' : var * ctyp -> ctyp
  val Lam'  : var * (var * ctyp) list * cexp -> cval
  val WApp' : cval * world -> cval
  val TApp' : cval * ctyp -> cval
  val WLam' : var * cval -> cval
  val TLam' : var * cval -> cval
  val Sham0' : cval -> cval
  val Zerocon' : primcon -> ctyp
  val EProj' : var * string * cval * cexp -> cexp

end
