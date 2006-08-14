
signature ILPRINT =
sig

    (* attempts to use type abbreviations to print
       datatypes if in scope. *)
    val ttolex : Context.context -> IL.typ -> Layout.layout

    (* type, expression, and declaration  to layout. *)
    val ttol : IL.typ -> Layout.layout
    val etol : IL.exp -> Layout.layout
    val dtol : IL.dec -> Layout.layout

end
