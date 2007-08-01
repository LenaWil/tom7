
signature CLOSURE =
sig

    exception Closure of string

    (* convert w e
       closure convert a closed expression e (at the world w)
       so that no Fns value has any free variables. *)
    val convert : CPS.world -> CPS.cexp -> CPS.cexp

end