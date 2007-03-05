(* Prior to closure conversion we perform a translation to establish an invariant:
   that every bound type variable has associated with it in context a value that
   corresponds to that type's dictionary. (At this level, a dictionary is an abstract
   thing; ultimately it will be used to contain the marshaling functions for the
   type so that polymorphic code can transfer data over the network.) The output of
   this translation achieves the binding invariant by three representation guarantees,
   which are listed below.

   Type variables are bound in only two places in the CPS language. The AllLam
   construct abstracts over worlds, types, and values. The ExternType imports an abstract
   type and binds it to a variable. In both cases, the type has kind 0, so we do not need
   to worry about dictionaries taking other dictionaries.

   XXX existential types also, but shouldn't see those before closure conversion!

   Representation Invariant 1: For AllLam { worlds, types = t1..tn, vals = x1..xm, body },
   m >= n and x1..xn are the dictionaries for the types t1..tn, respectively.

   Representation Invariant 2: For AllApp { f, worlds, types = t1..tn, vals = v1..vm },
   m >= n and v1..vn are the dictionaries for types t1..tn, respectively.

   Representation Invariant 3: For ExternType (v, lab, vlo, _), vlo is SOME (v', lab')
   where lab' is a symbol standing for the dictionary for the abstract type at the
   label lab.

*)

structure CPSDict :> CPSDICT =
struct

    exception CPSDict of string

    fun translate _ = raise CPSDict "unimplemented"
end
