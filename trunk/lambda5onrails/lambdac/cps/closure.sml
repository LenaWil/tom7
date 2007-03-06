
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

   (a, b, c) -> d         ==>    Eenv. { 

   The AllLam construct allows quantification over value variables;
   we will also closure convert it whenever there is at least one value
   variable. These lambdas act like 


   In addition to closure converting Fn(s) expressions, we also have
   to closure convert type abstractions. This is because these will be
   later converted into lambdas (actually value lambdas), so they must
   be hoisted and closed. Because TLam takes only a type argument, we
   must add a value argument so that it can be be passed the
   environment. Since their bodies are values, we need a value version
   of the Proj expression that allows projection out of the components
   of the environment. Because TApp is itself a value and closure
   calls involve the elimination of a (type) existential, we need a
   value version of that as well.

   This means that something like /\a/\b fn x => (y, z)
   will be converted to

    LAB_A =   /\(a|env1). vlet y = #1 env1
                          vlet z = #2 env1
                          closure < LAB_B , (a | y, z) >
    LAB_B =   /\(b|env2). vlet y = #1 env2
                          vlet z = #2 env2
                          closure < LAB_B , (a, b | y, z) >
                   
       . . .

   wait, this sucks because now I need to stick types inside values as
   data; in other words, I need modules. The type "forall t. A(t)"
   translates into Exists m. m * forall t. m _> A(t), where _> is the
   value arrow, and the closure for (/\b...) is 
   pack ((a | y, z), tlam t. vlam m. etc.) as Exists etc.

   I don't want to go down this route because the type theory becomes
   much more complicated.
   
   Perhaps we can do the dictionary stuff before closure conversion?
   It just means that we have to preserve the dictionary invariants
   through more phases, although maybe we could do marshalling
   insertion right after closure conversion. Then only closure
   conversion needs to watch out for the dictionary invariant, but it
   was already going to be complicated cf above. *)



structure Closure :> CLOSURE =
struct
    
    
    

end
