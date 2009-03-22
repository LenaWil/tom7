
(* Support for Laser Suspension Womb.
   This is proprietary one-off hardware, so you probably want to disable
   this.
*)
signature WOMB =
sig
    
    (* Detect the presence of the device and initialize.
       Gotta call this before doing anything else in this structure.
       Returns true if the hardware was detected. *)
    val detect : unit -> bool

    (* Signal the device immediately.

       XXX: This is boring. We have more semantic info than this
       and should use it.
       *)
    val signal : unit -> unit


end
