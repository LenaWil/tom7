
(* Support for Laser Suspension Womb.
   This is proprietary one-off hardware, so you probably want to disable
   this.
*)
signature RAW_WOMB =
sig
    
    (* Detect the presence of the device and initialize.
       Gotta call this before doing anything else in this structure.
       Returns true if the hardware was detected. *)
    val detect : unit -> bool

    (* Did we already find and initialize the womb? *)
    val already_found : unit -> bool

    (* Signal the device, setting these raw bits. *)
    val signal_raw : Word32.word -> unit

(*
             ,---,----,         +---------+
     hat    / a b  e f \        |       i |  board
   (front) /  c d  g h  \       |         |
          |              |      +---------+
           `---~~~~-----'
              brim
*)

    type light
    val A : light
    val B : light
    val C : light
    val D : light
    val E : light
    val F : light
    val G : light
    val H : light
    val I : light

    (* Call periodically *)
    val heartbeat : unit -> unit

end

signature WOMB =
sig

    include RAW_WOMB

    (* Set exactly these lights on *)
    val signal : light list -> unit

    (* change just this light's state *)
    val liteon : light -> unit
    val liteoff : light -> unit

end