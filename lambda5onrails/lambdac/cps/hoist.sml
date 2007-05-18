(* After closure conversion, every lambda expression is closed with
   respect to value variables. The goal of the hoisting transformation
   is to lift those lambda expressions to the top level, so that they
   are refered to by code labels rather than being spelled out
   explicitly in the code. These labels are what are actually passed
   around at runtime, rather than expressions.

   Hoisting is just a matter of naming a thing and then using the name
   for that thing instead of the thing itself. This requires that the
   thing not be dependent on its context; i.e., closed.
   
   The problem is that while these lambdas are closed to dynamic
   components because of closure conversion, they are not necessarily
   composed to static components (type and world variables). We don't
   need to do closure conversion for such things (they will be erased)
   but because of our dictionary passing invariant, we would have to
   introduce dynamic dictionaries to correspond to any abstracted
   static types. This is annoying for sure, perhaps expensive, and
   possibly impossible.

   So instead, we first eliminate the need for the dictionary
   invariant by generating the actual dictionaries where needed. After
   this we can make static abstractions and applications with little
   cost.
   
   (So see undict.sml.)
*)
