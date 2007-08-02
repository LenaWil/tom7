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

   Type variables are bound by the type constructor Mu as well, but
   not by the corresponding term constructors. We do not need to worry
   about these type variables at all because they cannot appear in
   terms.

   Because types are not associated with worlds (although we may have
   such "located types" in future work; see notes/typeatworld.txt),
   the dictionaries should not be associated with worlds either--we
   might transfer control to another world in the scope of some
   abstract type and then need to marshal some value of that abstract
   type. The dictionary passing invariant ensures that the dictionary
   is always bound as a universal variable.

   Representation Invariant 1: 
    For AllLam { worlds, types = t1..tn, vals = x1..xm, body },
    m >= n and x1..xn are the universal dictionaries for the types t1..tn, 
    respectively. Each should be shamrocked, and they are immediately
    unshamrocked in the body.

   Representation Invariant 2: 
    For AllApp { f, worlds, types = t1..tn, vals = v1..vm },
    m >= n and v1..vn are the dictionaries for types t1..tn, respectively,
    each shamrocked.

   Representation Invariant 3: 
    For ExternType (v, lab, vlo, _), vlo is SOME (v', lab')
    where lab' is a symbol standing for the dictionary for the 
    abstract type at the label lab. The dictionary must be exported as 
    a uvar. 

   (the following two are irrelevant here since there will be no
    tpacks/tunpacks, but they will be introduced in CPS conversion.
    These are also permanent: we need to keep the dictionaries inside
    existential packages for the purposes of marshaling at runtime;
    see undict.sml)

   Representation Invariant 4: 
    For TUnpack, the first element of the list will always be the
    shamrocked dictionary for the type existentially bound. It is
    immediately unshamrocked in the body to put it in the context.
     (Notwithstanding the above, this unshamrocking can be eliminated
      as an optimization, since it is irrelevant for marshaling.)

   Representation Invariant 5: 
    TPack always packs a list (sham dict :: ...) as in #4.


   We also do the same for worlds, associating each static world
   variable in scope with a representation. This is considerably
   simpler because worlds are unstructured (just constants or
   variables). 

     XXXWD: world representation invariants here
     
     for allarrow, we put the wdicts first in the val list.
     for {}A, we translate it to {w} allarrow{w wdict}.A
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
           AllArrow' { worlds = worlds, 
                       tys = tys,
                       vals = 
                       map (Shamrock' o TWdict' o W) worlds @
                       map (Shamrock' o Dictionary' o TVar') tys @ 
                       map trt vals,
                       body = trt body }
       (* actually, letd might generate these when it is implemented in the frontend *)
       | WExists _ => raise CPSDict "BUG: shouldn't have existential worlds yet (?)"
       (* these are bugs *)
       | TExists _ => raise CPSDict "BUG: shouldn't have existential types yet"
       | Shamrock (w, t) => Shamrock' (w, AllArrow' { worlds = nil, tys = nil, vals = [TWdict' w], body = trt body })
       | Primcon(DICTIONARY, _) => raise CPSDict "BUG: shouldn't see dicts before introducing dicts!"
       | _ => pointwiset trt typ)

    (* unlike DICT_SUFFIX, this is arbitrary *)
    fun mkdictvar v = Variable.namedvar (Variable.tostring v ^ "_d")

    (* G is a set of uvars that were eliminated with *)
    fun tre G exp =
      (case cexp exp of
         TUnpack _ => raise CPSDict "BUG: shouldn't see existential type tunpack yet"
       (* actually, letd might generate these when it is implemented in the frontend *)
       | WUnpack _ => raise CPSDict "BUG: shouldn't see existential world wunpack yet (?)"
       | ExternType (v, s, NONE, e) => 
           (* kind of trivial *)
           ExternType' (v, s, SOME (mkdictvar v, s ^ DICT_SUFFIX), tre e)
       | ExternType _ => raise CPSDict "BUG: extern type already had dict?"
       (* nb. nothing to do for extern worlds because those declare constants, not bind variables *)
       | _ => pointwisee trt trv tre exp)

    and trv G value =
      (case cval value of
         TPack _ => raise CPSDict "BUG: shouldn't see extential type tpack yet"
       | VTUnpack _ => raise CPSDict "BUG: shouldn't see extential type vtunpack yet"
       | Dictfor _ => raise CPSDict "BUG: shouldn't see dicts yet"
       | AllLam { worlds : var list, tys : var list, vals : (var * ctyp) list, body : cval } => 
           let 
             (* the argument variable, the unshamrocked uvar, its type *)
             val wvars = map (fn w => (mkdictvar w, mkdictvar w, Shamrock' ` TWdict' ` W w)) worlds
             val dvars = map (fn t => (mkdictvar t, mkdictvar t, Shamrock' ` Dictionary' ` TVar' t)) tys
           in
             AllLam' { worlds = worlds, 
                       tys = tys,
                       vals = 
                          map (fn (sh, _, t) => (sh, t)) wvars @ 
                          map (fn (sh, _, t) => (sh, t)) dvars @ 
                          vals, 
                       body = 
                         (* open up the shamrocks, then continue with translated body.
                            (world dicts and typ dicts are treated the same here) *)
                         foldr (fn ((sh, di, t), v) => VLetsham'(di, Var' sh, v)) (trv body) (wvars @ dvars)
                       }
           end
       | AllApp { f : cval, worlds : world list, tys : ctyp list, vals : cval list } => 
             AllApp' { f = trv f, worlds = worlds, tys = tys,
                       (* add the dictionaries to the beginning of the value list *)
                       vals = 
                         map (fn w => Sham0' ` WDictfor' w) worlds @
                         map (fn t => Sham0' ` Dictfor' t) tys @ 
                         map trv vals }
       | _ => pointwisev trt trv tre value)

    fun translate e = tre V.Set.empty e
end
