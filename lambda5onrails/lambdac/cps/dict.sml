(* Prior to closure conversion we perform a translation to establish
   an invariant: that every bound type variable within a value or
   expression has associated with it in context a value that
   corresponds to that type's dictionary. (At this level, a dictionary
   is an abstract thing; ultimately it will be used to contain the
   marshaling functions for the type so that polymorphic code can
   transfer data over the network.) The output of this translation
   achieves the binding invariant by a set of representation
   guarantees, which are listed below.

   Type variables are bound in only three places in the CPS language.
   The AllLam construct abstracts over worlds, types, and values. The
   ExternType imports an abstract type and binds it to a variable. The
   third is the TUnpack construct, which unpacks a existential type.
   However, we do not expect to see TPack and TUnpack until after
   closure conversion, so we do not translate them here. In all cases,
   the bound type has kind 0, so we do not need to worry about
   dictionaries taking other dictionaries.

   Type variables are bound by the type constructor Mu as well, but not
   by the corresponding term constructors. We do not need to worry about
   these type variables at all because they cannot appear in terms.

   Representation Invariant 1: For AllLam { worlds, types = t1..tn, vals = x1..xm, body },
   m >= n and x1..xn are the dictionaries for the types t1..tn, respectively.

   Representation Invariant 2: For AllApp { f, worlds, types = t1..tn, vals = v1..vm },
   m >= n and v1..vn are the dictionaries for types t1..tn, respectively.

   Representation Invariant 3: For ExternType (v, lab, vlo, _), vlo is SOME (v', lab')
   where lab' is a symbol standing for the dictionary for the abstract type at the
   label lab.

   (the following two are irrelevant here since there will be no tpacks/tunpacks,
    but they will be introduced in CPS conversion)

      ### XXX maybe this should be in the syntax? like a label/list of values ###
   Representation Invariant 4: For TUnpack, the body will always be a record with two
   fields { value, dict }, where the dictionary is the dict component.

   Representation Invariant 5: TPack always packs a record { value, dict } as in #4.

*)

structure CPSDict :> CPSDICT =
struct

    exception CPSDict of string

    open CPS

    infixr 9 `
    fun a ` b = a b

    val DICT_SUFFIX = "_dict"
    val DICT_LAB = "dict"
    val VALUE_LAB = "value"

    fun trt typ =
      (case ctyp typ of
      (* this is the only case we do anything interesting in *)
         AllArrow {worlds, tys, vals, body} => 
           AllArrow' { worlds = worlds, tys = tys,
                       vals = map (fn v => Primcon' (DICT, [TVar' v])) tys @ map trt vals, 
                       body = trt body }
       (* these are bugs *)
       | TExists _ => raise CPSDict "BUG: shouldn't have existential types yet"
       | Primcon(DICT, _) => raise CPSDict "BUG: shouldn't see dicts before introducing dicts!"
       | _ => pointwiset trt typ)

    (* unlike DICT_SUFFIX, this is basically arbitrary *)
    fun mkdictvar v = Variable.namedvar (Variable.tostring v ^ "_d")

    fun tre exp =
      (case cexp exp of
         TUnpack _ => raise CPSDict "BUG: shouldn't see existential type tunpack yet"
       | ExternType (v, s, NONE, e) => 
           (* kind of trivial *)
           ExternType' (v, s, SOME (mkdictvar v, 
                                    s ^ DICT_SUFFIX), tre e)
       | ExternType _ => raise CPSDict "BUG: extern type already had dict?"
       | _ => pointwisee trt trv tre exp)

    and trv value =
      (case cval value of
         TPack _ => raise CPSDict "BUG: shouldn't see extential type tpack yet"
       | Dictfor _ => raise CPSDict "BUG: shouldn't see dicts yet"
       | AllLam { worlds : var list, tys : var list, vals : var list, body : cval } => 
             AllLam' { worlds = worlds, tys = tys, vals = map mkdictvar tys @ vals, 
                       body = trv body }
       | AllApp { f : cval, worlds : world list, tys : ctyp list, vals : cval list } => 
             AllApp' { f = trv f, worlds = worlds, tys = tys,
                       (* add the dictionaries to the beginning of the value list *)
                       vals = map Dictfor' tys @ map trv vals }
       | _ => pointwisev trt trv tre value)

    fun translate e = tre e
end
