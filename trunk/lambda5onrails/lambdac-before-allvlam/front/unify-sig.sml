
signature UNIFY =
sig
    exception Unify of string

    val new_ebind : unit -> 'a IL.ebind ref

    val unify  : Context.context -> IL.typ -> IL.typ -> unit

    val unifyw : Context.context -> IL.world -> IL.world -> unit

end
