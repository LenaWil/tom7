
(* Support for Laser Suspension Womb.
   This is proprietary one-off hardware, so you probably want to disable
   this. (Though it's harmless if it does not detect one.)
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
     hat    j/ a b  e f \l       |       i |  board
   (front) k/  c d  g h  \m      |         |
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
    val J : light
    val K : light
    val L : light
    val M : light

    (* Everything, except board. *)
    val lights : light Vector.vector
    (* Just LEDs *)
    val leds : light Vector.vector
    val lasers : light Vector.vector

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

    val liteson : light list -> unit
    val litesoff : light list -> unit

    (* cyclic pattern repeating at specific rate *)
    type pattern
    (* Number of ticks, then a list of sets of lights. *)
    val pattern : Word32.word -> light list list -> pattern

    (* Force the next in sequence. *)
    val next : pattern -> unit

    (* Call as often as you wish. *)
    val maybenext : pattern -> unit

    val disable : unit -> unit
    val enable : unit -> unit

end