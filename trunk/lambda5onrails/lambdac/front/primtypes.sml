
structure PrimTypes :> PRIMTYPES =
struct

    exception PrimTypes of string
    
    structure V = Variable
    open IL
    open Primop

    fun wv f = f (V.namedvar "a")

    fun typeof "halt" = 
      wv (fn a =>
          SOME(PHalt, Poly({worlds = nil, tys = [a]}, ([], TVar a))))

      | typeof _ = NONE

end
