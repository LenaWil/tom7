
signature TOCPS =
sig
    (* convert k e

       convert a (finalized) IL unit e to a CPS expression
       XXX and set of global world constants? *)
    val convert : IL.ilunit -> IL.world -> CPS.cexp (* * string list *)

    (* clear some debugging stuff; call between converted programs *)
    val clear : unit -> unit

    exception ToCPS of string

end
