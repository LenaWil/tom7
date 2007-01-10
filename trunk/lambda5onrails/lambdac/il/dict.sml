
(* Dictionary-passing transformation. 

   This pass transforms polymorphic code to insert dictionaries at
   'Get' expressions. A dictionary maps abstract type variables to
   a pair of values that allow marshalling and unmarshalling that
   type. A compiled 'Get' needs to marshall a closure built from
   the environment of the body of the Get (and its evaluation context).
   At this point in the compiler we have not generated the closures
   yet, so we don't know what they'll contain (and so what types will
   need to be marshalled). So, we record all the abstract types currently
   in scope along with the marshalling functions for them in the dictionary.

   Abstract types are introduced in two ways: Polymorphic abstraction
   (which, at the IL level, can occur only at Fun and Val bindings), and
   Extern types. In order to ensure that we have a dictionary entry for every
   type in scope, we must arrange for such values to accompany these abstract
   types in the places in which they are introduced.
   
   For polymorphic abstraction, we rewrite the abstraction sites to
   add one value argument for each type argument. The only kind of
   abstraction site is the polymorphic Val binding, and the only kind
   of instantiation site is the PolyVar. (Actually, there are also
   bindings and occurrences for valid variables, and we need to carry
   out the same translation there.)

   For each type variable bound in a Val binding, we wrap the value
   with a VLam binding a dictionary associated with that type variable.
   We keep these associations in our translation context.

   When reaching a PolyVar, we use VApp to apply the abstracted value
   to the appropriate dictionaries. We have the types that the polyvar
   is instantiated with, so this is just a matter of looking up those
   types' dictionaries in the translation context.

   
   For extern types, we introduce an additional ExternVal for each
   ExternType. The value has type t dict, where t is the extern type.
   We must also export such dictionaries. These are simply added
   for each exported type.

*)


structure ILDict :> ILDICT =
struct

  exception ILDict of string


  fun transform _ = raise ILDict "unimplemented"

end