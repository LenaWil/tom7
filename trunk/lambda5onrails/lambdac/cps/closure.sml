
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
   functions. This is closure converted in the standard way (see below).

   (a, b, c) -> d         ==>    E env. [env dict, (env, a, b, c) -> d]

   For mutually recursive bundles, we have:

   |(a, b, c) -> d;              E env. [env dict, |(env, a, b, c) -> d;
    (e, f, g) -> h|       ==>                       (env, e, f, g) -> h|]



   The AllLam construct allows quantification over value variables;
   we will also closure convert it whenever there is at least one value
   variable. These lambdas are converted pretty much the same way as
   regular lambdas.

   { w; t; t dict } -> c

          ==>

   E env. [env dict, { w; t; env, t dict } -> c]

   


*)


structure Closure :> CLOSURE =
struct
    
  exception Closure of string
    
  fun convert _ = raise Closure "unimplemented"
end
