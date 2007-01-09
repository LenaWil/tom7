
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
   add one value argument for each type argument. In the case of polymorphic
   Fun bindings, we can add these value arguments to the arguments of the
   function:

   fun ('a, 'b, 'g) f(x, y, z) = e

    -->

   fun ('a, 'b, 'g) f(Da, Db, Dg, x, y, z) = e

   In the case of Val bindings, we must lambda-abstract the 
   value itself.

*)


structure ILDict :> ILDICT =
struct

  exception ILDict of string


  fun transform _ = raise ILDict "unimplemented"

end