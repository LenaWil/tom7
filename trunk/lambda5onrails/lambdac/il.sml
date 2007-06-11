
structure IL =
struct

  type intconst = IntConst.intconst

    type label = string
    type var = Variable.var

    (* arm in a datatype(sum). might be a carrier ("of
       t") or not. If a carrier, t might be a type
       that is always allocated (e.g., a non-empty
       record) or it might be something we can't
       determine the allocation status of (like a
       type variable). *)
    datatype 'typ arminfo =
      NonCarrier
    | Carrier of { definitely_allocated : bool,
                   carried : 'typ }
      
    fun arminfo_map f NonCarrier = NonCarrier
      | arminfo_map f (Carrier { definitely_allocated, carried }) =
      Carrier { definitely_allocated = definitely_allocated,
                carried = f carried }

    datatype worldkind = KJavascript | KBytecode

    (* worlds : index the typing judgment *)
    datatype world =
      WEvar of world ebind ref
    | WVar of var
    | WConst of string

    (* types : classifiers for values *)
    and typ =
        TVar of var
      | TRec of (label * typ) list
      (* bool true => total 
         functions are n-ary.
         *)
      | Arrow of bool * typ list * typ
      | Sum of (label * typ arminfo) list
      (* pi_n (mu  v_0 . typ_0
               and v_1 . typ_1
               and ...)
         0 <= n < length l, length l > 0.

         all variables are bound in all arms.

         when unrolling, choose nth arm and
         substitute:

         typ_n [ (pi_0 mu .. and ..) / v_0,
                 (pi_1 mu .. and ..) / v_1,
                 ... ]
         *)
      | Mu of int * (var * typ) list
      | Evar of typ ebind ref

      | TVec of typ
      | TCont of typ

      | TRef of typ

      | TTag of typ * var

      | At of typ * world
      | TAddr of world

      | Arrows of (bool * typ list * typ) list

    (* type constructors *)
    and con =
        Typ of typ
      | Lambda of typ list -> typ

    (* existential *)
    and 'a ebind =
        Free of int
      | Bound of 'a

    (* polymorphic type *)
    and 'a poly = Poly of { worlds : var list,
                            tys    : var list } * 'a

    and value = 
        Polyvar  of { tys : typ list, worlds : world list, var : var }
      | Polyuvar of { tys : typ list, worlds : world list, var : var }
      | Int of intconst
      | String of string
      | VRecord of (label * value) list
      | VRoll of typ * value
      | VInject of typ * label * value option

      | Fns of 
        { name : var,
          arg  : var list,
          dom  : typ list,
          cod  : typ,
          body : exp,
          (* should always inline? *)
          inline : bool,
          (* these may be conservative estimates *)
          recu : bool,
          total : bool } list

      (* select one of the functions in a bundle *)
      | FSel of int * value

      (* XXX no longer representing dictionaries at the IL level *)

      (* apply (total)value to value *)
(*
      | VApp of value * value
      | VLam of var * typ * value

      (* the dictionary for this type, assuming dlist gives
         the dictionaries for the abstract type variables. *)
      | VDict of typ * (var * value) list
*)

      (* XXX apparently need VVApp for valid values...? *)

    and exp =
        Value of value
      
      (* application is n-ary *)
      | App of exp * exp list

      | Record of (label * exp) list
      (* #lab/typ e *)
      | Proj of label * typ * exp
      | Raise of typ * exp
      (* var bound to exn value within handler *)
      | Handle of exp * var * exp

      | Seq of exp * exp
      | Let of dec * exp
      | Unroll of exp
      | Roll of typ * exp

      | Get of { addr : exp,
                 dest : world,
                 typ  : typ,
                 (* dlist : (var * value) list option, *)
                 body : exp }

      | Throw of exp * exp
      | Letcc of var * typ * exp

      (* tag v with t *)
      | Tag of exp * exp

      | Untag of { typ : typ,
                   obj : exp,
                   target : exp,
                   bound : var, (* within yes *)
                   yes : exp,
                   no : exp }

      (* apply a primitive to some expressions and types *)
      | Primapp of Primop.primop * exp list * typ list

      (* sum type, object, var (for all arms but not default), 
         branches, default.
         the label/exp list need not be exhaustive.
         *)
      | Sumcase of typ * exp * var * (label * exp) list * exp
      | Inject of typ * label * exp option

      (* for more efficient treatment of blobs of text. *)
      | Jointext of exp list

    and dec =
        Do of exp
        (* quantifiers on the outside -- no poly recursion *)
        (* XXX5 could make PolyVal that requires syntactic value.. *)
      | Val of (var * typ * exp) poly
        (* XXX5 uval *)
      | Tagtype of var
        (* tag of typ in tagtype *)
      | Newtag of var * typ * var

      | ExternWorld of label * worldkind
      | ExternVal   of (label * var * typ * world option) poly
      (* extern type (a, b) t *)
      | ExternType  of kind * label * var


    and ilunit = (* XXX5 *)
        Unit of dec list * export list

    and export =
      (* XXX5 I don't see how we could ever export a world *)
        ExportWorld of label * world
      | ExportType of var list * label * typ
        (* if world is none, then export valid *)
      | ExportVal of (label * typ * world option * value) poly

    (* the kind is the number of curried arguments. 0 is kind T. *)
    withtype kind = int



    (* now a derived form *)
    fun Var v = Polyvar { tys = nil, worlds = nil, var = v }
    (* expand to linear search *)
    fun Tagcase (t, obj, bound, vel, def) = 
      let
        val vo = Variable.namedvar "tagcase"
        fun go nil = def
          | go ((v, e) :: rest) =
          Untag { typ = t,
                  obj = Value (Var vo),
                  target = Value (Var v),
                  bound = v,
                  yes = e,
                  no = go rest }
      in
        Let (Val (Poly ({worlds=nil, tys=nil}, (vo, t, obj))),
             go vel)
      end
    
    datatype tystatus = Regular | Extensible
    datatype idstatus = 
        Normal 
      | Constructor 
      (* the var is the tag, in scope, that should be used
         to deconstruct this tagged expression *)
      | Tagger of var 
      | Primitive of Primop.primop

end
