
signature TOCPS =
sig
    (* convert k e

       convert a (finalized) IL unit e to a CPS expression
       that evaluates the unit for its effect and then halts. *)
    val convert : IL.ilunit -> CPS.cexp

    (* clear some debugging stuff; call between converted programs *)
    val clear : unit -> unit

    exception ToCPS of string

end
