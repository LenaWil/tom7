(* The code in dict.sml establishes an invariant, before closure
   conversion, that associates a dynamic value with each free static
   type variable, so that at any point in the program we can construct
   the dictionary for a type.

   The dictionary is a dynamic representation of a type. It is used as
   an input to the marshal and unmarshal functions. We also put
   dynamic representations inside existential packages; we would not
   be able to marshal e.g. "exists t. t" even given a representation
   of the type "exists t. t" because the hidden type could have many
   different forms dynamically.

   Maintaining this invariant through the hoisting transformation (see
   hoist.sml) would be painful. In this pass we remove the need for
   the invariant by making the uses of dictionaries explicit, so that
   the ability to create dictionaries at any program point is no
   longer required. (This will prevent us from packing existentials
   at arbitrary program points too, but we shouldn't need to do this
   any more.)

   Dictionaries are used as arguments to the primitives marshal and
   unmarshal. Conceptually these have the following types:

     marshal    :  forall a. a dict * a -> bytes
     unmarshal  :  forall a. a dict * bytes -> a option
   

   Communication only happens at the go_cc construct, which requests
   that (remotely) a continuation value be run on an argument value,
   both of which are @ the remote world. In order to make such a
   request, we must marshal the continuation value and the argument
   value to get some bytes.

   On the receiving end, we'll take those bytes, unmarshal them into
   the pair of argument and continuation, and do the application. This
   code always looks like

     entry = 
       lam (b : bytes) .
         leta p @ w' = 
           unmarshal < (exists arg . {arg dict, arg cont, arg}) at w' > 
              ( dictfor ( (exists arg . {arg dict, arg cont, arg}) at w' ),
                b ) in
         unpack _, { _, f, a } the p in
         run f on a

   in other words, the go_cc construct will become go_mar, which takes
   an address and bytes and always invokes the same entry point above.
   The use of unmarshal doesn't need any dictionaries--we always
   unmarshal at the same type. (Existential packages have type
   representations within them, which is where we get the necessary
   dynamic information from.) In fact, the entry lambda above is
   totally closed.

   We always unmarshal at the same type (well, one type for each
   host), and so we always marshal at the same type.

     go_cc (addr : w' addr, f : argt cont, a : argt)

   -->

     p = hold(w') (pack <argt, { dictfor argt, f, a }>
                   as exists arg . { arg dict, arg cont, arg })

     b : bytes = marshal < (exists arg . { arg dict, arg cont, arg }) at w' > 
                    ( dictfor ((exists arg . { arg dict, arg cont, arg }) at w'), p )

     go_mar (addr, b)


   Even though dictionaries are arguments to the marshal function, the
   real purpose of the dictionary passing invariant is to create the
   dictionaries that are stored in existential packages. The
   dictionary argument to the marshal primitive is always the same
   closed existential type and the marshal function gets the
   information it needs recursively from the dictionary stored inside
   the existential package.


   This translation is very simple. We simply need to find occurrences
   of the go_cc construct and apply the rule above. (The insertion of
   the entry point can happen in another phase since it doesn't need
   dictionaries.) We must keep track of the association of type variables
   to dictionaries so that we can generate the dictionary for the new
   'pack' we create above.

   We'll also translate any 'dictfor' so that it only operates on closed
   types.

*)
