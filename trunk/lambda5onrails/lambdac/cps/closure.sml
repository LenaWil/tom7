
(* This is a dirt simple implementation of closure conversion.

   The Hemlock series of compilers had a very compilcated closure
   conversion algorithm that attempted to balance a number of
   constraints to produce as good code as possible. This led to a very
   complex and error-prone implementation. One of the reasons was that
   it was annoying to consider the implications of mutual recursion
   (and implement it), but difficult to just punt on that case without
   making the implementation incorrect.

   This language is more complicated than the Hemlock CPS IL, so the
   closure conversion algorithm cannot be as ambitious. In addition to
   the new machinery having to do with the modal features, we also
   must maintain a dictionary-passing invariant (see dict.sml) during
   this translation.

   Therefore the new strategy is to do something simple and general,
   but then implement things like direct calls for the common case in
   a later optimization pass. This has the advantage that we can more
   easily punt on any difficult cases like mutual recursion. It also may
   subsume and/or be assisted by other optimizations like known-argument
   and tuple flattening optimizations. It also shortens the path to a
   working but slow compiler.

   Several things need to be closure converted. First, obviously, is
   the Fns expression, which is a bundle of mutually-recursive
   functions. The conversion of this is a little tricky because of
   mutual recursion. The straightforward thing is this:

   fns f(x). e1           ==>    
   and g(y). e2


    pack ( ENV ; [dictfor ENV, env = { fv1 = fv1, ... fvn = fvn },
          fns f(env, x). 
              let fv1 = #fv1 env
                    ...
                  (: create closures for calls to f and g within e1 :)
                  f = (pack ( ENV ; [dictfor ENV, env = env, f] ))
                  g = (pack ( ENV ; [dictfor ENV, env = env, g] ))
                  .. [[e1]]
          and g(env, y).
                  .. same ..
          ])

         where ENV is the record type { fv1 : t1, ... fvn : tn }.

   so the type |(a, b, c) -> d; (e, f, g) -> h|
   becomes     E ENV. [ENV dict, ENV, |(env, [[a]], [[b]], [[c]]) -> [[d]];
                                       (env, [[e]], [[f]], [[g]]) -> [[h]]|]

   And the type (a, b, c) -> d
   becomes     E ENV. [ENV dict, ENV, (env, [[a]], [[b]], [[c]]) -> [[d]]]

   So the question is, what to do with the fsel construct, which has this typing
   rule?

      e : | ts1 -> t1 ; ts2 -> t2 ; ... tsn -> tn | @ w      0 <= m < n
     ------------------------------------------------------------ fsel
                     e . m   :  tsm -> tm @ w

   the translation must take on this type:

      e : E ENV. [ENV dict, ENV, |(env :: ts1) -> t1; ...
                                  (env :: tsn) -> tn|] @ w      0 <= m < n
     ------------------------------------------------------------------------------ fsel?
       e . m   :  E ENV. [ENV dict, ENV, (env, tsm) -> tm]  @ w

   and it must be a value.

   There's only one way to do this. e.m must translate into 

   unpack e as (ENV; [de, env, fs])           <- unpack must be a value then
   in  pack ( ENV ; [de, env, fs.m] ) 

   in many situations (especially for m = 0 and fs a singleton) we should be able to
   optimize this to avoid the immediate packing and unpacking.


   Question: is it really the best choice to have the fns construct dynamically bind
   the individual function variables within itself, or should it bind the bundle and
   then we use fsel to make friend calls? Both seem to work, but the latter seems
   a bit more uniform.


   Other features need to be closure converted as well. They are
   simpler but less standard.

   The AllLam construct allows quantification over value variables;
   we will also closure convert it whenever there is at least one value
   variable. These lambdas are converted pretty much the same way as
   regular lambdas.

   { w; t; t dict } -> c

          ==>

   E env. [env dict, { w; t; env, t dict } -> c]
              XXX HERE

*)


structure Closure :> CLOSURE =
struct
    
  exception Closure of string
    
  fun convert _ = raise Closure "unimplemented"
end
