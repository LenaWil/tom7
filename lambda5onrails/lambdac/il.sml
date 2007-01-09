
structure IL =
struct

  type intconst = Word32.word

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

    (* worlds : index the typing judgment *)
    datatype world =
      WEvar of world ebind ref
    | WVar of var

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
        (* int indicates which of the mutually recursive function
           values it is *)
      | Fn of 
        int * { name : var,
                arg  : var list,
                dom  : typ list,
                cod  : typ,
                body : exp,
                (* should always inline? *)
                inline : bool,
                (* these may be conservative estimates *)
                recu : bool,
                total : bool } list

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
                 typ  : typ,
                 (* FIXME No, an association list *)
                 dict : exp option,
                 body : exp }

      | Throw of exp * exp
      | Letcc of var * typ * exp

      (* tag v with t *)
      | Tag of exp * exp
      (* tagtype, object, var (for all arms), branches, def *)
      | Tagcase of typ * exp * var * (var * exp) list * exp

      (* apply a primitive to some expressions and types *)
      | Primapp of Primop.primop * exp list * typ list

      (* sum type, object, var (for all arms), branches, default.
         the label/exp list need not be exhaustive.
         *)
      | Sumcase of typ * exp * var * (label * exp) list * exp
      | Inject of typ * label * exp option

      (* for more efficient treatment of blobs of text. *)
      | Jointext of exp list

      | Deferred of exp Util.Oneshot.oneshot

    and dec =
        Do of exp
        (* quantifiers on the outside -- no poly recursion *)
        (* XXX could make PolyVal that requires syntactic value.. *)
      | Val of (var * typ * exp) poly
      | Tagtype of var
        (* tag of typ in tagtype *)
      | Newtag of var * typ * var

    (* the kind is the number of curried arguments. 0 is kind T. *)
    withtype kind = int

    (* now a derived form *)
    fun Var v = Polyvar { tys = nil, worlds = nil, var = v }

    datatype tystatus = Regular | Extensible
    datatype idstatus = 
        Normal 
      | Constructor 
      (* the var is the tag, in scope, that should be used
         to deconstruct this tagged expression *)
      | Tagger of var 
      | Primitive of Primop.primop

end
