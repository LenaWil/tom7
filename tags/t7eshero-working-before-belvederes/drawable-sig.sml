
(* Type of drawable elements, for creating chains of stuff.
   Kinda some OO poop. *)
signature DRAWABLE =
sig

    type drawable

    val nodraw : drawable
    val draw : drawable -> unit
    (* Notify that the screen has resized *)
    val resize : drawable -> unit
    (* Should be called periodically *)
    val heartbeat : drawable -> unit

    val drawable : { draw : unit -> unit,
                     resize : unit -> unit,
                     heartbeat : unit -> unit } -> drawable

    val drawonly : (unit -> unit) -> drawable
    val don't : unit -> unit
end