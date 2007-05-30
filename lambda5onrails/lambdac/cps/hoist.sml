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

   Okay, it is not that simple. We can hoist out the code after
   abstracting it to make the term closed, but there is one more
   contextual factor, which is that typing judgments are made with
   respect to worlds. We may have:

    /\ w . hold_w lam x:int. E(...w...)

   where now the lambda (and so E) are typed at the world w. Hoisting
   this naively would produce:

   LAB = /\w'. lam x. E(...w'...)

   MAIN = /\ w . hold_w LAB<w>

   So LAB's type is      forall w'. int cont   @ ???

   It can't be at w' because the the binder for that variable is
   within the term, and it can't be at w because that isn't in scope
   either. Following the thorny garden path for a moment, the only
   remaining possibility is that we universally quantify that world as
   well:

   LAB = sham w''. /\ w'. lam x. E(...w'...)

   MAIN = /\ w. hold_w letsham u = LAB      // u ~ forall w'. int cont
                       in u<w>              // u<w> : int cont @ w

   This seems okay, but the fact that w'' and w' are not equal may cause
   problems. (Equally, the fact that w'' is not equal to some other worlds
   around could cause problems too?) For example, we might try to do
   something like

      leta x = hold_w' v
      ... f(x) ...
      
   which will only typecheck at w'.

   A straightforward variant is to not forall-quantify the world that the
   term is typed at; instead it is sham-quantified. The above example
   becomes

   LAB = sham w'. lam x. E(...w'...)
   MAIN = /\ w. hold_w letsham u = LAB    // u ~ int cont
                       in u               // u : int cont @ w

   and all is well. Or is it? Why should we believe that we can
   make any typing judgment schematic in its world?

   Consider the following:

     // start at world "home"
     extern world server
     extern val format : unit -> unit  @  server
     
     hold_server lam x. format()

   After (simplistic) closure conversion:

     ...
     hold_server pack _ as _ the <lam [x, format]. leta f : unit -> unit @ server = format 
                                                   in f (),
                                  hold_server format>

   We might translate this to:


     LAB = sham w'. lam [x,           format]. leta f = format in f ()
                          : int @ w'   : (unit -> unit) at w' @ w'

     LAB : {} ((int * ((unit -> unit) at ???)) cont)   @ wherever

     oops! The sham-bound w' would have to appear in the type under the {}, which
     is not allowed, since it is not bound by the type. (Maybe it should be??)
          []A = -forall w. A at w
          {}A = +forall w. A at w

   We can sidestep this issue in this context by not using {} but wrapping the world
   quantification into the label mechanism. So, using a new hypothetical type system,


     LAB(w') = w'. lam [x : int, format : unit -> unit at w']. 
                    leta f = format in f ()

     LAB ~ (int * (unit -> unit  at ???) cont)
       .. still not obvious what to say here; we could write

     LAB[w] : (int * (unit -> int  at w) cont) @ w
       .. that is, LAB is really a family of labels, each with a different type.
       .. or, put differently, lab is a typing judgment and value, parametric in some world.


   Then we have

     MAIN = extern world server
            extern val format : unit -> unit  @  server

            hold_server pack _ as _ the <LAB[server], hold_server format>

   everything is okay here.

   Note this had nothing to do with "extern world" and "extern val"; we could have
   equivalently written:

     /\server. lam (format' : unit -> unit  at server).
         leta format = format'
         in  ...

   ... because extern world just binds a variable with no condition that it be the
   "same" as other extern declarations for that same world.

   Now try:

   extern world server
   hold_server
      lam ().
         extern val format : unit -> unit  @  server
         ...

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
      val ctr = ref 0
      (* PERF. we should be able to merge alpha-equivalent labels here,
         which would probably yield substantial $avings. *)
      (* Take code and return a label after inserting it in the global
         code table. *)
      fun insert (arg as (ws, ts, vael)) =
          let
              (* XXX could derive it from a function name in vael? *)
              val l = "L_" ^ Int.toString (!ctr)
          in
              ctr := !ctr + 1;
              accum := arg :: !accum;
              l
          end


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

               val l = insert (w, t, vael)
                   
             in
               AllApp' { f = Codelab' l, worlds = map W w, tys = map TVar' t, vals = nil }
             end
         | _ => pointwisev ct cv ce v)

      val program' = ce program
    in
      (* FIXME wrap program' with global bindings *)
      raise Hoist "unimplemented"
    end

end
