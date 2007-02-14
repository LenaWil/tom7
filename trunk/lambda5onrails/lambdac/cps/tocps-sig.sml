
signature TOCPS =
sig
    (* convert k e

       convert an IL expression e to a CPS expression.
       The continuation k is called to generate the "tail"
       of the expression from its final value. Typically
       this is something like (fn v => Finish v).
       *)
    val convert : IL.ilunit -> CPS.cpsunit

    (* clear some debugging stuff; call between converted programs *)
    val clear : unit -> unit

    exception ToCPS of string

end
