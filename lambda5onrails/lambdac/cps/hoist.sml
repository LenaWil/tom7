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

   Now that undictionarying is done, hoisting is accomplished simply.
   Introduce a new value "Label l", where l is a global name for a
   piece of code. We then traverse the program. For each Lams that we
   see, we compute its free world and type variables. We then abstract
   over those, and insert that abstracted bit of code into a global
   place. The occurrence is replaced with AllApp(Label l, tys,
   worlds).

*)

structure Hoist :> HOIST =
struct

  infixr 9 `
  fun a ` b = a b

  exception Hoist of string
  open CPS
  structure V = Variable

  fun hoist home program =
    let
      val accum = ref nil
      (* PERF. we should be able to merge alpha-equivalent labels here,
         which would probably yield substantial $avings. *)
      (* Take code and return a label after inserting it in the global
         code table. *)
      fun insert _ = raise Hoist "unimplemented"


      (* types do not change. *)
      fun ct t = t

      (* don't need to touch expressions, except the values within them *)
      fun ce e = pointwisee ct cv ce e

      (* for values, only Lams is relevant

         XXX I think we need to hoist alllam when it has a value argument,
         since it is also closure-converted.
         *)
      and cv v =
        (case cval v of
           Lams vael =>
             let
               val { w, t } = freesvarsv v
               val w = V.Set.foldr op:: nil w
               val t = V.Set.foldr op:: nil t

               val () = print "Hoist FWV: "
               val () = app (fn v => print (V.tostring v ^ " ")) w
               val () = print "\nHoist FTV: "
               val () = app (fn v => print (V.tostring v ^ " ")) t
               val () = print "\n"

             in
               (* FIXME do something ... *)
               Lams' vael
               (* raise Hoist "unimplemented" *)
             end
         | _ => pointwisev ct cv ce v)

      val program' = ce program
    in
      (* FIXME wrap program' with global bindings *)
      raise Hoist "unimplemented"
    end

end
