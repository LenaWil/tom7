
signature ELABORATE =
sig

    exception Elaborate of string

(*     val elab : Context.context -> IL.world -> EL.exp -> IL.exp * IL.typ *)

    val elaborate : EL.exp -> IL.exp * IL.typ

end