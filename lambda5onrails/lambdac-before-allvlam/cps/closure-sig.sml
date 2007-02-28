
signature CLOSURE =
sig

    (* raised on error *)
    exception Closure of string

    (* closure convert an expression so that no Fns value
       has any free variables. *)
    val convert : CPS.cexp -> CPS.cexp

end